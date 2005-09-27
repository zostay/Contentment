package Contentment::Response;

use strict;
use warnings;

our $VERSION = '0.04';

use Contentment::Hooks;
use Contentment::Log;
use Contentment::Request;
use IO::NestedCapture ':subroutines';

=head1 NAME

Contentment::Response - Handles Contentment response handling

=head1 DESCRIPTION

This is the class responsible for outputting the responses to a request. It provides an API for manipulating that output, such as specifying additional headers to output, specifying the MIME type, status, etc.

=over

=item Contentment::Response->error_page($message)

On error, this tries to find or generate a suitable error page for the given error message C<$message>.

=cut

sub error_page {
	my $class = shift;
	my $ERROR = shift;

#	# If they've given an error document, use it.
#	my $very_bad_stuff = 0;
#	if ($conf->{'error_page'}) {
#		my $vfs = Contentment::VFS->new;
#		my $error_file = $vfs->lookup_source($conf->{'error_page'});
#		eval {
#			$error_file->generate(
#				error => $ERROR,
#			);
#		};
#
#		# Very bad stuff. We'll fall back to the stupid and boring default. 
#		if ($@) {
#			$log->error("error generating error page $error_file: $@");
#			$very_bad_stuff = 1;
#		}
#	}

	# Don't use an else in case of an error above. We use this stupid and
	# boring default if there's no error_page or if very bad stuff happened
	# generating the error page.
	#
	# This is hard-coded to make sure this works as much as possible.
#	unless ($conf->{'error_page'} || $very_bad_stuff) {
#		my $context = Contentment->context;
#		$context->header->{'-type'} = 'text/html';
#		$context->header->{'-status'} = 404;
#		$context->original_kind('text/html');

		my $q = Contentment::Request->cgi;
		print $q->header(
			-type => 'text/html',
			-status => '404',
		);
		print "<?xml version=\"1.0\"?>\n";
		print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n";
		print "    \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n";
		print "<html xmlns=\"http://www.w3.org/1999/html\">\n";
		print "<head><title>404 Not Found</title></head>\n";
		print "<body>\n";
		print "<h1>Not Found</h1>\n";
		print "<p>An error occurred finding or generating the content: $ERROR</p>\n";
		print "<p>You may wish to contact the webmaster about this problem.</p>\n";
		print "</body></html>\n";
		Contentment::Response->top_kind('text/html');
#	}
}

=item $component = Contentment::Response->response($path)

This returns the $component that would be used to give a response for the given path, C<$path>. If no C<$path> is given, it will default to the C<path_info> of the L<CGI> object.

=cut

sub resolve {
	my $class = shift;
	my $path  = shift;
	
	my $iter = Contentment::Hooks->call_iterator('Contentment::Response::resolve');
	while ($iter->next) {
		$path = $iter->call($path);
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

	# Find the component responsible for rendering output
	my $component = Contentment::Response->resolve;

	# Did we find anything?
	if ($component) {
		Contentment::Log->debug("Resolution found component %s", [$component]);

		# If it's a container and the URL doesn't end in '/', we need to fix it
		# so that relative URLs are handled as expected.
		if ($component->is_container && $q->path_info !~ /\/$/) {
			Contentment::Log->debug("Redirecting directory %s", [$q->path_info]);
			Contentment::Response->redirect($q->path_info."/", %{ $q->Vars });

		# Otherwise, generate it!
		} else {

			# Call the begin hook for any pre-response output.
			Contentment::Log->debug("Calling hook Contentment::Response::begin");
			capture_in_out {
				Contentment::Hooks->call('Contentment::Response::begin');
			};

			# Pipe the output from ::begin into the input for generation.
			IO::NestedCapture->set_next_in(IO::NestedCapture->get_last_out);

			# Capture the output and check for errors.
			Contentment::Log->debug("Generating response for component %s", [$component]);
			eval {
				capture_in_out {
					Contentment::Response->properties({
						map { ($_ => $component->get_property($_)) }
						$component->properties 
					});

					$component->generate(%{ $q->Vars });
					Contentment::Response->top_kind ||
						Contentment::Response->top_kind($component->generated_kind(%{ $q->Vars }));
				};
			};

			# Bad stuff. Generate an error page. Throw away input captured thus
			# far.
			if ($@) {
				Contentment::Log->error("Error generating %s: %s", [$component, $@]);

				capture_in_out {
					Contentment::Response->error_page($@);
				};
			}
		}

	# No file to render. Show an error.
	} else {
		Contentment::Log->error("No component found for %s", [$q->path_info]);
		capture_in_out {
			Contentment::Response->error_page("404 Not Found");
		};
	}

	# Give the post-process response hooks their chance to filter the output
	# from the top file component. These hooks MUST move the input to the output
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
					Contentment::Response->error_page($@);
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

=item $properties = Contentment::Response-E<gt>properties

=item Contentment::Response-E<gt>properties(\%properties)

Used to set certain bits of information about the generated file. This is most useful for theming or otherwise learning information about a request after generation.

This method is called an the properties are initialized just prior to generation from the component's properties. After that they may be read or modified by calling the method to return a reference to a hash.

=cut

my %properties;
sub properties {
	my $class = shift;
	my $properties = shift;

	if ($properties) {
		%properties = %$properties;
	}

	return \%properties;
}

=back

=head2 HOOKS

=over

=item Contentment::Resposne::begin

Handlers of this hook can expect no arguments, but their output will be captured and passed on to the component generator. It runs right before component generator.

=item Contentment::Response:end

Handlers of this hook can expect the input from the generated output or the previous handler's output. The output will be captured for output to the client.

=item Contentment::Response::resolve

These handlers take a path argument and should ultimately result in in a component capable of generating content. The result of the previous handler is passed as the argument to the next.

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
