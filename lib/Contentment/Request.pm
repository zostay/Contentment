package Contentment::Request;

use strict;
use warnings;

our $VERSION = '0.01';

use CGI;
use Contentment::Hooks;
use Contentment::Log;

=head1 NAME

Contentment::Request - Class responsible for managing incoming requests

=head1 DESCRIPTION

This class consumes an HTTP request and then presents the current request through the interface provided. Contentment is meant to target different web platforms (CGI, FastCGI, libwww-perl, mod_perl, etc.). Each of these present a different API for accessing the HTTP request information. This interface tries to simplify things by presenting a uniform request interface for all.

Rather than re-invent yet another interface to add to the list above, we'd rather just use an existing object. We use L<CGI> to present this interface. It's not ideal because it also presents a lot of response functionality that should be found in L<Contentment::Response>. However, it is the only interface that is both popular and works uniformly with nearly any target platform with very little effort. This also gives you additional functionality, such as HTML code generation, fill-in form generation, and some other tools that might also be useful in your code. However, the returning of response information is the job of L<Contentment::Response>, so these features of L<CGI> will remain unused (though, L<Contentment::Response> probably uses them internally as they are quite handy).

=head2 METHODS

=over

=item $query = Contentment::Request-E<gt>cgi

Retrieves a copy of the CGI object or undef if the request hasn't be initialized yet.

=cut

my $cgi;
sub cgi {
	return $cgi;
}

=item Contentment::Request-E<gt>begin_cgi

This shouldn't be called outside of a L<Contentment> handler method. It tells the handler to load the request from standard input and the environment.

This calls the C<Contentment::Request::begin> hook.

=cut

sub begin_cgi {
	Contentment::Log->info("Initializing CGI object from CGI request.");
	$cgi = CGI->new;
	Contentment::Hooks->call('Contentment::Request::begin', $cgi);
}

=item Contemtent::Request-E<gt>end_cgi

This shouldn't be called outside of a L<Contentment> handler method. It calls the C<Contentment::Request::end> hook.

=cut

sub end_cgi {
	Contentment::Log->info("Shutting down the CGI request.");
	Contentment::Hooks->call('Contentment::Request::end', 
		Contentment::Request->cgi);
}

=back

=head2 HOOKS

=over

=item Contentment::Request::begin

These handlers are passed a single argument. This will be a copy of the just initialized L<CGI> object.

=item Contentment::Request::end

These handlers are passed a single argument. This will be a copy of the L<CGI> object for the request.

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
