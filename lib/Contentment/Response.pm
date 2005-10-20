package Contentment::Response;

use strict;
use warnings;

our $VERSION = '0.08';

use Carp;
use Contentment::Generator;
use Contentment::Hooks;
use Contentment::Log;
use Contentment::Request;
use IO::NestedCapture ':subroutines';

=head1 NAME

Contentment::Response - Handles Contentment response handling

=head1 DESCRIPTION

This is the class responsible for outputting the responses to a request. It provides an API for manipulating that output, such as specifying additional headers to output, specifying the MIME type, status, etc.

=over

=item $generator = Contentment::Response->error($exception)

=item $generator = Contentment::Response->error($status, $message, $description, $detail)

When called, it will use the "Contentment::Response::error" hook to attempt to locate a handler capable of handling the error message. The first form simply names an error message, C<$exception>, to print. This method will always return a generator object (i.e., if none of the hook handlers return one or there aren't any handlers, the method will create one).

The second form allows for more fine grained control. The C<$status> is the numeric HTTP error code to return and the C<$message> is a short named description of the error. The C<$description> is a longer descriptive text and C<$detail> is debug information that probably ought not be displayed to the user (or not directly).

All arguments are optional.

=cut

sub error {
	my $class = shift;

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
		$error = Contentment::Generator->new;
		$error->set_property(error       => 1);
		$error->set_property(status      => $status);
		$error->set_property(message     => $message);
		$error->set_property(description => $description);
		$error->set_property(detail      => $detail);

		$error->set_generated_kind(sub { 'text/html' });

		$error->set_generator(sub {
			Contentment::Response->header->{'-status'} = "$status $message";
			print "<?xml version=\"1.0\"?>\n";
			print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n";
			print "    \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n";
			print "<html xmlns=\"http://www.w3.org/1999/html\">\n";
			print "<head><title>$status $message</title></head>\n";
			print "<body>\n";
			print "<h1>$message</h1>\n";
			print "<p>An error occurred finding or generating the content: $description</p>\n";
			print "<p>You may wish to contact the webmaster about this problem.</p>\n";
			print "<!-- $detail -->\n";
			print "</body></html>\n";
		});
	}
		
	return $error;
}

sub redirect {
	my $class = shift;
	my $url   = shift;

	unless ($url =~ /:/) {
		$url = Contentment::Request->cgi->url(-base => 1).'/'.$url;
	}

	my @query;
	while (my ($key, $value) = splice @_, 0, 2) {
		push @query, "$key=$value";
	}

	if (@query) {
		$url .= '?'.join('&', @query);
	}

	my $redirect = Contentment::Generator->new;
	$redirect->set_generator(sub {
		Contentment::Response->header->{'-status'} = "302 Found";
		Contentment::Response->header->{'-location'} = $url;
	});

	return $redirect;
}


=item $generator = Contentment::Response->resolve($path)

This returns the generator that would be used to give a response for the given path, C<$path>. If no C<$path> is given, it will default to the C<path_info> of the L<CGI> object.

This method always returns a generator. If no generator is found using the "Contentment::Response::resolve" hook or an error occurs during the process, then the C<error> method is called to return a "Not Found" document. You can check for that circumstance as follows:

  my $generator = Contentment::Response->resolve($some_path);
  if ($generator->get_property('error')) {
      # It's an error document
  } else {
	  # It's the document we requested
  }

=cut

sub resolve {
	my $class = shift;
	my $path  = shift || Contentment::Request->cgi->path_info;
	my $orig  = $path;

	eval {	
		my $iter = Contentment::Hooks->call_iterator('Contentment::Response::resolve');
		while ($iter->next) {
			$path = $iter->call($path);
		}
	};

	if ($@) {
		Contentment::Log->error("Contentment::Response::resolve experienced an error while searching for %s: %s", [$orig,$@]);
		$path = Contentment::Response->error($@);
	} elsif (!$path) {
		Contentment::Log->warning("Contentment::Response::resolve found no match for %s.", [$orig]);
		$path = Contentment::Response->error(
			404, 'Not Found', 
			"Could not find anything for the given path: $orig",
			Carp::longmess("Could not find anything for the given path: $orig")
		);
	}

	return $path;
}

=item Contentment::Response->handle_cgi

This should not be called outside of a L<Contentment> handler method. It returns the completed response.

=cut

sub handle_cgi {
	# Get the CGI object from the request class
	my $q = Contentment::Request->cgi;
	Contentment::Log->info("Handling request %s", [$q->path_info]);

	# Find the generator responsible for rendering output
	my $generator = Contentment::Response->resolve;

	Contentment::Log->debug("Resolution found generator %s", [$generator]);

	# Call the begin hook for any pre-response output.
	Contentment::Log->debug("Calling hook Contentment::Response::begin");
	capture_in_out {
		Contentment::Hooks->call('Contentment::Response::begin');
	};

	# Pipe the output from ::begin into the input for generation.
	IO::NestedCapture->set_next_in(IO::NestedCapture->get_last_out);

	# Capture the output and check for errors.
	Contentment::Log->debug("Generating response for generator %s", [$generator]);
	capture_in_out {
		eval {
			Contentment::Response->generator($generator);

			Contentment::Response->top_kind ||
				Contentment::Response->top_kind($generator->generated_kind(%{ $q->Vars }));
			$generator->generate(%{ $q->Vars });
		};

		# Bad stuff. Generate an error page. Throw away input captured thus
		# far.
		if ($@) {
			Contentment::Log->error("Error generating %s: %s", [$generator, $@]);

			my $error = Contentment::Response->error(
				500, 'Script Error', $@
			);

			$error->generate;
		}
	};

	# Give the post-process response hooks their chance to filter the output
	# from the top file generator. These hooks MUST move the input to the output
	# or the output of the original generated file will be lost. As such, we
	# don't bother to run these if there are no hooks.
	if (Contentment::Hooks->count('Contentment::Response::end')) {
		Contentment::Log->debug("Calling hook Contentment::Response::end");
		
		my $iter = Contentment::Hooks->call_iterator('Contentment::Response::end');
		while ($iter->next) {
			IO::NestedCapture->set_next_in(IO::NestedCapture->get_last_out);
			eval {
				capture_in_out {
					$iter->call;
				};
			};
	
			# Bad stuff. Generate an error page.
			if ($@) {
				Contentment::Log->error("Response post-process handler failure: %s", [$@]);
				capture_in_out {
					Contentment::Response->error($@)->generate;
				};
			}
		}
	} else {
		Contentment::Log->debug("Skipping hook Contentment::Response::end, no handlers registered.");
	}

	# Take the final captured output and print out the response
	Contentment::Log->debug("Sending response to standard output");
	my $final_output = IO::NestedCapture->get_last_out;
	unless (Contentment::Response->header_sent) {
		print $q->header(%{ Contentment::Response->header });
		Contentment::Response->header_sent;
	}
	print <$final_output>;

	# Done.
}

=item $test = Contentment::Response-E<gt>header_sent

=item Contentment::Response-E<gt>header_sent($header_sent)

Returns a true value if the headers were already printed as part of the request. Set to a true value if you send headers.

=cut

my $header_sent = 0;
sub header_sent {
	my $class = shift;
	my $new_sent = shift;

	$header_sent = defined($new_sent) ? $new_sent : $header_sent;
}

=item $header = Contentment::Response-E<gt>header

Returns a reference to a hash to store header information in. This hash will be passed to the L<CGI> C<header> function.

=cut

my $header = {};
sub header { return $header }

=item $top_kind = Contentment::Response-E<gt>top_kind

=item Contentment::Response-E<gt>top_kind($kind)

Used to reflect the current file kind of the top level response. This should be initially set during content generation by a call to the C<generated_kind> method of the file type plugin generating the output. It, then, may be modified further by later filters. It starts with an initial value of the empty string C<"">.

=cut

my $top_kind = '';
sub top_kind {
	my $class = shift;
	my $kind  = shift;

	return $top_kind = defined($kind) ? $kind : $top_kind;
}

=item $generator = Contentment::Response-E<gt>generator

This is used to fetch the top-most generator for the request.

=cut

my $generator;
sub generator {
	my $class = shift;
	my $gen   = shift;
	$generator = $gen if $gen;
	return $generator;
}

=back

=head2 HOOKS

=over

=item Contentment::Resposne::begin

Handlers of this hook can expect no arguments, but their output will be captured and passed on to the generator. It runs right before generator.

=item Contentment::Response:end

Handlers of this hook can expect the input from the generated output or the previous handler's output. The output will be captured for output to the client.

=item Contentment::Response::resolve

These handlers take a path argument and should ultimately result in in a generator object (see L<Contentment::Generator>). The result of the previous handler is passed as the argument to the next.

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
