package Contentment::Response;

use strict;
use warnings;

our $VERSION = '0.02';

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
#	}
}

=item Contentment::Response->handle_cgi

This should not be called outside of a L<Contentment> handler method. It returns the completed response.

=cut

sub handle_cgi {
	# Get the CGI object from the request class
	my $q = Contentment::Request->cgi;
	Contentment::Log->info("Handling request %s", [$q->path_info]);

	# Find the component responsible for rendering output
	my $component = Contentment::Hooks->call('Contentment::Response::resolve');

	# Did we find anything?
	if ($component) {

		# If it's a container and the URL doesn't end in '/', we need to fix it
		# so that relative URLs are handled as expected.
		if ($component->is_container && $q->path_info !~ /\/$/) {
			Contentment::Log->debug("Redirecting directory %s", [$q->path_info]);
			Contentment::Response->redirect($q->path_info."/", %{ $q->Vars });

		# Otherwise, generate it!
		} else {

			# Call the begin hook for any pre-response output.
			capture_in_out {
				Contentment::Hooks->call('Contentment::Response::begin');
			};

			# Pipe the output from ::begin into the input for generation.
			IO::NestedCapture->set_next_in(IO::NestedCapture->get_last_out);

			# Capture the output and check for errors.
			eval {
				capture_in_out {
					$component->generate(%{ $q->Vars });
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
		capture_in_out {
			Contentment::Response->error_page("404 Not Found");
		};
	}

	# Give the post-process response hooks their chance to fileter the output
	# from the top file component.
	IO::NestedCapture->set_next_in(IO::NestedCapture->get_last_out);
	eval {
		capture_in_out {
			Contentment::Hooks->call('Contentment::Response::end');
		};
	};

	# Bad stuff. Generate an error page.
	if ($@) {
		Contentment::Log->error("Response post-process handler failure: %s", [$@]);
		capture_in_out {
			Contentment::Response->error_page($@);
		};
	}

	# Take the final captured output and print out the response
	my $final_output = IO::NestedCapture->get_last_out;
	unless (Contentment::Response->header_sent) {
		print $q->header(%{ Contentment::Response->header });
		Contentment::Response->header_sent;
	}
	print <$final_output>;

	# Done.
}

my $header_sent = 0;
sub header_sent {
	my $class = shift;
	my $new_sent = shift;

	$header_sent = defined($new_sent) ? $new_sent : $header_sent;
}

my $header = {};
sub header { return $header }

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
