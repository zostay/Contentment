package Contentment::Request;

use strict;
use warnings;

our $VERSION = '0.011_033';

use base 'Class::Singleton';

use CGI;
use Contentment::Hooks;
use Contentment::Log;
use IO::Handle;
use IO::NestedCapture qw( CAPTURE_STDOUT );

# Don't fail if FastCGI is not available.
eval "use CGI::Fast";
eval "use FCGI";

=head1 NAME

Contentment::Request - Class responsible for managing incoming requests

=head1 DESCRIPTION

This class consumes an HTTP request and then presents the current request through the interface provided. Contentment is meant to target different web platforms (CGI, FastCGI, libwww-perl, mod_perl, etc.). Each of these present a different API for accessing the HTTP request information. This interface tries to simplify things by presenting a uniform request interface for all.

Rather than re-invent yet another interface to add to the list above, we'd rather just use an existing object. We use L<CGI> to present this interface. It's not ideal because it also presents a lot of response functionality that should be found in L<Contentment::Response>. However, it is the only interface that is both popular and works uniformly with nearly any target platform with very little effort. This also gives you additional functionality, such as HTML code generation, fill-in form generation, and some other tools that might also be useful in your code. However, the returning of response information is the job of L<Contentment::Response>, so these features of L<CGI> will remain unused (though, L<Contentment::Response> probably uses them internally as they are quite handy).

=head2 METHODS

=over

=item $request = $context-E<gt>request

Before using any of the other methods of this class, you must first get a reference to the request object. This method is valid for anything happening during or after the "Contentment::Request::begin" hook until after the "Contentment::Request::end" hook finishes.

=item $query = $request-E<gt>cgi

Retrieves a copy of the CGI object or undef if the request hasn't be initialized yet.

=cut

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub cgi {
    my $self = shift;
	return $self->{cgi};
}

=item $kind = $request-E<gt>final_kind

This method may be called to ask what kind of file the request wants returned. This involves calling the "Contentment::Request::final_kind" hook. The hook will be called at most once per request and the result will be cached here if this method is called more than once. If no handlers are set or none of the called handlers can identify the final kind, then the empty string (C<"">) will be returned.

=cut

sub final_kind {
    my $self = shift;
    
    if (!ref $self) {
        use Carp;
        confess "Bad invocant: $self";
    }

	return $self->{final_kind} if defined $self->{final_kind};

	my $cgi = $self->cgi;
	my $iter = Contentment::Hooks->call_iterator('Contentment::Request::final_kind');
	while ($iter->next) {
		$self->{final_kind} = $iter->call($cgi);
		last if defined $self->{final_kind};
	}

	return $self->{final_kind} ||= '';
}

=item Contentment::Request-E<gt>begin_cgi($ctx)

This shouldn't be called outside of a L<Contentment> handler method. It tells the handler to load the request from standard input and the environment.

This calls the C<Contentment::Request::begin> hook.

=cut

sub begin_cgi {
    my $class = shift;
    my $ctx   = shift;

	Contentment::Log->info("Initializing CGI object from CGI request.");
    my $self        = $class->new;
	$self->{cgi}    = CGI->new;
    $ctx->{request} = $self;
	Contentment::Hooks->call('Contentment::Request::begin', $ctx);
}

=item Contemtent::Request-E<gt>end_cgi

This shouldn't be called outside of a L<Contentment> handler method. It calls the C<Contentment::Request::end> hook.

=cut

sub end_cgi {
    my $class = shift;
    my $ctx   = shift;

	Contentment::Log->info("Shutting down the CGI request.");
	Contentment::Hooks->call('Contentment::Request::end', $ctx);

    # Request informatio no longer available from now on.
    delete $ctx->{request};
}

=item Contentment::Request-E<gt>begin_fast_cgi

This shouldn't be called outside of a L<Contentment> handler method. It tells the handler to the load the FastCGI request.

This calls the C<Contentment::Request::begin> hook.

=cut

sub begin_fast_cgi {
    my $class = shift;
    my $ctx   = shift;

    my $self        = $class->new;
    $ctx->{request} = $self;

    # Log startup
    Contentment::Log->info("Initialize FastCGI object from CGI::Fast request.");

    # We need to do some custom tweaking to FastCGI before this will work quite
    # right. We'll let FastCGI take over STDIN so CGI::Fast will initially read
    # from there. However, we won't let it have STDOUT because we need to usurp
    # that ourselves. We will capture that and then route the output to our own
    # file handle after words in end_fast_cgi().
    unless (defined $CGI::Fast::Ext_Request) {
        $self->{outfh} = IO::Handle->new;
        $CGI::Fast::Ext_Request 
            = FCGI::Request(\*STDIN, $self->{outfh}, \*STDERR);
    }

    # Now capture the output file handle for our own nefarious purposes
    IO::NestedCapture->start(CAPTURE_STDOUT);

    # Try to get a connection to accept
    if ($self->{cgi} = CGI::Fast->new) {
        untie *STDIN;
        Contentment::Hooks->call('Contentment::Request::begin', $ctx);
        return 1;
    } 
    
    # Quit if there are no more FastCGI connections to be had
    else {
        IO::NestedCapture->stop(CAPTURE_STDOUT);
        return 0;
    }
}

=item Contentment::Request->end_fast_cgi

This shouldn't be called outside of a L<Contentment> handler method. It calls the C<Contentment::Request::end> hook.

=cut

sub end_fast_cgi {
    my $class = shift;
    my $ctx   = shift;

    my $self  = $ctx->{request};

	Contentment::Log->info("Shutting down the CGI request.");
	Contentment::Hooks->call('Contentment::Request::end', $ctx);

    IO::NestedCapture->stop(CAPTURE_STDOUT);

    my $infh  = IO::NestedCapture->get_last_out;
    my $outfh = $self->{outfh};
    $outfh->print(<$infh>);

    # Request no longer available after this point
    delete $ctx->{request};
}

=back

=head2 CONTEXT

This class adds the following context methods:

=over

=item $request = $context-E<gt>request

Fetches the request object for the current request.

=cut

sub Contentment::Context::request {
    my $ctx = shift;
    return defined $ctx->{request} ? $ctx->{request} :
        Contentment::Exception->throw(message => "Request is not available.");
}

=item $cgi = $context-E<gt>cgi

This is a short cut for:

  $cgi = $context->request->cgi;

=cut

sub Contentment::Context::cgi {
    my $ctx = shift;
    return defined $ctx->{request} ? $ctx->{request}->cgi :
        Contentment::Exception->throw(message => "Request CGI state is not available.");
}

=back

=head2 HOOKS

=over

=item Contentment::Request::begin

These handlers are passed a single argument. This will be a copy of the context object.

=item Contentment::Request::end

These handlers are passed a single argument. This will be a copy of the context object.

=item Contentment::Request::final_kind

These handlers are passed a single argument. This will be a copy of the context object. 

These handlers should try to identify the kind of file the request wants rendered. The file "kind" is a bit of a nebulous idea, but is often a MIME Type or something similar and can be used by various plugins to figure out how to render the page. The first handler that returns a value other than C<undef> forms the result of the hook. The rest of the handlers will not be called.

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1

