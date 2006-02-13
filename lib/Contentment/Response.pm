package Contentment::Response;

use strict;
use warnings;

our $VERSION = '0.011_033';

use base 'Class::Singleton';

use Carp;
use Contentment::Exception;
use Contentment::Generator;
use Contentment::Hooks;
use Contentment::Log;
use Contentment::Request;
use IO::NestedCapture ':subroutines';
use URI;

=head1 NAME

Contentment::Response - Handles Contentment response handling

=head1 DESCRIPTION

This is the class responsible for outputting the responses to a request. It provides an API for manipulating that output, such as specifying additional headers to output, specifying the MIME type, status, etc.

=over

=item $response = $context-E<gt>response

Before you can do anything, you call any of these methods, you will need to retrieve the response object from the context. This object will be available as soon just before the "Contentment::Response::begin" hook is called and remains available until immediately after the call to "Contentment::Response::end".

=cut

sub new {
    my $class = shift;
    return bless {}, $class;
}

=item $generator = $response-E<gt>error($exception)

=item $generator = $response-E<gt>error($status, $message, $description, $detail)

When called, it will use the "Contentment::Response::error" hook to attempt to locate a handler capable of handling the error message. The first form simply names an error message, C<$exception>, to print. This method will always return a generator object (i.e., if none of the hook handlers return one or there aren't any handlers, the method will create one).

The second form allows for more fine grained control. The C<$status> is the numeric HTTP error code to return and the C<$message> is a short named description of the error. The C<$description> is a longer descriptive text and C<$detail> is debug information that probably ought not be displayed to the user (or not directly).

All arguments are optional.

=cut

sub error {
	my $self = shift;

	my ($status, $message, $description, $detail);	
	if (@_ > 1) {
		push @_, '' until @_ >= 4; # pad to prevent uninitialized warnings
		($status, $message, $description, $detail) = 
			map { defined($_) ? $_ : '' } @_;
	} else {
		$status      = 400;
		$message     = 'Error';
		$description = shift;
		$detail      = '';
	}

	my $error = Contentment::Hooks->call('Contentment::Response::error');

	unless ($error) {
		$error = Contentment::Generator->generator('Plain', {
            properties => {
                error       => 1,
                status      => $status,
                message     => $message,
                description => $description,
                detail      => $detail,
                kind        => 'text/html',
            },
            source => sub {
                Contentment->context->response->header->{'-status'} = "$status $message";
                print <<"END_OF_HTML";
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/html">
<head><title>$status $message</title></head>
<body>
<h1>$message</h1>
<p>An error occurred finding or generating the content: $description</p>
<p>You may wish to contact the webmaster about this problem.</p>
<!-- $detail -->
</body></html>
END_OF_HTML
		    },
        });
	}
		
	return $error;
}

=item $generator = $response-E<gt>redirect($url)

=item $generator = $response-E<gt>redirect($url, %query)

This method is given a URL and will create a generator that returns a temporary redirect to that URL. The C<$url> may either be a L<URI> object or a string. The URL may be either absolute or relative. If the URL is relative, it will be converted to an absolute address using the C<base_url()> method of the current L<Contentment::Site>, thus the address should be relative to the current root path.

If you wish, you may also add a set of query variables on the end of the list. These will be appended to the URL following a "?" and will be formatted and escaped for you.

=cut

sub redirect {
	my $self = shift;
	my $url  = shift;

    # If it's not a URI object, make it so
    unless (ref $url) {
        $url = URI->new($url);
    }

    $url = $url->abs(Contentment::Site->current_site->base_url);

    if (@_) {
        $url->query(@_);
    }

	my $redirect = Contentment::Generator->generator('Plain', {
        properties => {
            title       => 'Redirect',
            description => "Redirect to $url",
            kind        => '',
        },
        source => sub {
            my $response = Contentment->context->response;
            $response->header->{'-status'} = "302 Found";
            $response->header->{'-location'} = $url->canonical->as_string;
        },
    });

    Contentment::Log->debug("Created redirect generator to: $url");

	return $redirect;
}


=item $generator = $response-E<gt>resolve($path)

This returns the generator that would be used to give a response for the given path, C<$path>. If no C<$path> is given, it will default to the C<path_info> of the L<CGI> object.

This method always returns a generator. If no generator is found using the "Contentment::Response::resolve" hook or an error occurs during the process, then the C<error> method is called to return a "Not Found" document. You can check for that circumstance as follows:

  my $generator = $ctx->response->resolve($some_path);
  if ($generator->get_property('error')) {
      # It's an error document
  } else {
	  # It's the document we requested
  }

=cut

sub resolve {
	my $self = shift;
	my $path = shift || Contentment->context->cgi->path_info;
	my $orig = $path;

	eval {	
		my $iter = Contentment::Hooks->call_iterator('Contentment::Response::resolve');
		while ($iter->next) {
			$path = $iter->call($path);
#            use Data::Dumper;
#            print STDERR Dumper($path);
		}
	};


	if ($@) {
		Contentment::Log->error(
            'Contentment::Response::resolve experienced an error while '
           .'searching for %s: %s', [$orig,$@]);

        if (my $x = Contentment::Exception->caught) {
            $path = $self->error(
                $x->status,
                $x->title,
                $x->message,
                $x->details."\n".$x->trace,
            );
        }

        else {
            $path = $self->error($@);
        }
	} elsif (!$path) {
		Contentment::Log->warning(
            'Contentment::Response::resolve found no match for %s.', [$orig]);
		$path = $self->error(
			404, 'Not Found', 
			"Could not find anything for the given path: $orig",
			Carp::longmess("Could not find anything for the given path: $orig")
		);
	}

	return $path;
}

=item Contentment::Response->handle_cgi($ctx)

This should not be called outside of a L<Contentment> handler method. It returns the completed response.

=cut

sub handle_cgi {
    my $class = shift;
    my $ctx   = shift;
    my $self  = $class->new;

    $ctx->{response} = $self;

	# Get the CGI object from the request class
	my $q = $ctx->cgi;
	Contentment::Log->info("Handling request %s", [$q->path_info]);

	# Find the generator responsible for rendering output
	my $generator = $self->resolve;

	Contentment::Log->debug("Resolution found generator %s", [$generator]);

	# Call the begin hook for any pre-response output.
	Contentment::Log->debug("Calling hook Contentment::Response::begin");
	capture_in_out {
		Contentment::Hooks->call('Contentment::Response::begin', $ctx);
	};

	# Pipe the output from ::begin into the input for generation.
	IO::NestedCapture->set_next_in(IO::NestedCapture->get_last_out);

	# Capture the output and check for errors.
	Contentment::Log->debug("Generating response for generator %s", [$generator]);
	capture_in_out {
		eval {
			$self->generator($generator);

			$self->top_kind ||
				$self->top_kind($generator->get_property('kind'));
			$generator->generate($q->Vars);
		};

		# Bad stuff. Generate an error page. Throw away input captured thus
		# far.
		if ($@) {
			Contentment::Log->error("Error generating %s: %s", [$generator, $@]);

            my $error;
            if (my $x = Contentment::Exception->caught) {
                $error = $self->error(
                    $x->status,
                    $x->title,
                    $x->message,
                    $x->details."\n".$x->trace,
                );
            }

            else {
                $error = $self->error(
                    500, 'Script Error', $@
                );
            }

			$error->generate;
		}
	};

	# Give the post-process response hooks their chance to filter the output
	# from the top file generator. These hooks MUST move the input to the output
	# or the output of the original generated file will be lost. As such, we
	# don't bother to run these if there are no hooks.
	if (Contentment::Hooks->count('Contentment::Response::filter')) {
		Contentment::Log->debug("Calling hook Contentment::Response::filter");
		
		my $iter = Contentment::Hooks->call_iterator('Contentment::Response::filter');
		while ($iter->next) {
			IO::NestedCapture->set_next_in(IO::NestedCapture->get_last_out);
			eval {
				capture_in_out {
					$iter->call($ctx);
				};
			};
	
			# Bad stuff. Generate an error page.
			if ($@) {
				Contentment::Log->error("Response post-process handler failure: %s", [$@]);
				capture_in_out {
                    my $error;

                    if (my $x = Contentment::Exception->caught) {
                        $error = $self->error(
                            $x->status,
                            $x->title,
                            $x->message,
                            $x->details."\n".$x->trace,
                        );
                    }

                    else {
                        $error = $self->error($@);
                    }

                    $error->generate;
				};
			}
		}
	} else {
		Contentment::Log->debug("Skipping hook Contentment::Response::filter, no handlers registered.");
	}

    # Last call to modify headers and stuff.
    Contentment::Hooks->call('Contentment::Response::end', $ctx);

	# Take the final captured output and print out the response
	Contentment::Log->debug("Sending response to standard output");
	my $final_output = IO::NestedCapture->get_last_out;
	unless ($self->header_sent) {
		print $q->header(%{ $self->header });
		$self->header_sent;
	}
	print <$final_output>;

	# Done. Clean-up.
    delete $ctx->{response};
}

=item $test = $response-E<gt>header_sent

=item $response-E<gt>header_sent($header_sent)

Returns a true value if the headers were already printed as part of the request. Set to a true value if you send headers. Once set to true, it cannot be set back to false.

=cut

sub header_sent {
	my $self     = shift;
	my $new_sent = shift || 0;

    $self->{header_sent} ||= $new_sent;

	return $self->{header_sent}; 
}

=item $header = $response-E<gt>header

Returns a reference to a hash to store header information in. This hash will be passed to the L<CGI> C<header> function.

=cut

sub header { 
    my $self = shift;
    $self->{header} ||= {};
    return $self->{header};
}

=item $top_kind = $response-E<gt>top_kind

=item $response-E<gt>top_kind($kind)

Used to reflect the current file kind of the top level response. This should be initially set during content generation by a call to the C<generated_kind> method of the file type plugin generating the output. It, then, may be modified further by later filters. It starts with an initial value of the empty string C<"">.

=cut

sub top_kind {
	my $self = shift;
	my $kind = shift;

    # set to default if not set
    $self->{top_kind} ||= '';

    # set to kind if given
    $self->{top_kind} = defined($kind) ? $kind : $self->{top_kind};

	return $self->{top_kind};
}

=item $generator = $response-E<gt>generator

This is used to fetch the top-most generator for the request.

=cut

sub generator {
	my $self = shift;
	my $gen  = shift;
	$self->{generator} = $gen if $gen;
	return $self->{generator};
}

=back

=head2 CONTEXT

This package adds the following context methods:

=over

=item $response = $context-E<gt>response

This returns the current response object for the response being generated. It is only valid during and between the "Contentment::Response::begin" and "Contentment::Response::filter" hooks.

=cut

sub Contentment::Context::response {
    my $ctx = shift;
    return defined $ctx->{response} ? $ctx->{response} :
        Contentment::Exception->throw(message => "Response is not available.");
}

=head2 HOOKS

=over

=item Contentment::Response::resolve

These handlers take a path argument and should ultimately result in in a generator object (see L<Contentment::Generator>). The result of the previous handler is passed as the argument to the next.

=item Contentment::Resposne::begin

Handlers of this hook can expect just the context as an argument. The output of these hooks will be captured and passed on to the generator. It runs right before generator.

=item Contentment::Response:filter

These handlers will be given the current context as an argument. Handlers of this hook can expect the input from the generated output or the previous handler's output. The output will be captured for output to the client.

=item Contentment::Response::end

Handlers of this hook can expect just the context as an argument. No special input is given and they should output nothing. This gives handlers one last shot to modify the the non-content aspects of the response (such as headers).

=item Contentment::Response::error

These handlers take the four arguments that the C<error> method accepts and should return either C<undef> or a generator object (see L<Contentment::Generator>) capable of returning an error page.

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
