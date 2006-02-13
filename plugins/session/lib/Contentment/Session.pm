package Contentment::Session;

use strict;
use warnings;

our $VERSION = '0.13';

use Contentment;
use Data::UUID;

use base 'Oryx::Class';

=head1 NAME

Contentment::Session - Session management for Contentment

=head1 DESCRIPTION

This is a session management module specifically designed for Contentment.

=cut

our $schema = {
	attributes => [
		{
			name => 'session_id',
			type => 'String',
			size => 36,
		},
		{
			name => 'session_data',
			type => 'Complex',
		},
	],
};

=head2 CONTEXT

This class adds the following context methods:

=over

=item $session_data = $context-E<gt>session

This method returns a reference to a hash containing the session data.

=cut

sub Contentment::Context::session {
    my $context = shift;
	return defined $context->{session} ? $context->{session}{data} :
        Contentment::Exception->throw(message => "Session is not available.");
}

=item $session_id = $context-E<gt>session_id

This method returns a reference to the session ID.

=cut

sub Contentment::Context::session_id {
    my $context = shift;
    return defined $context->{session} ? $context->{session}{id} :
        Contentment::Exception->throw(message => "Session is not available.");
}

=back

=head2 HOOK HANDLERS

This class defines the following hook handlers:

=over

=back

=item Contentment::install

Deploys the session class into the database.

=cut

sub install {
	__PACKAGE__->storage->deployClass(__PACKAGE__);
}

=item Contentment::Session::open_session

This handles the "Contentment::Request::begin" hook. It associates session information with the context and calles the "Contentment::Session::begin" hook.

=cut

sub open_session {
    my $ctx = shift;
	my $q   = $ctx->cgi;

	my $session_id = $q->cookie('SESSIONID');
    my $session_data;

	my $session;
	if ($session_id) {
		($session) = Contentment::Session->search({ session_id => $session_id });
		if ($session) {
			Contentment::Log->debug("Reusing existing SESSIONID $session_id");
			$session_data = $session->session_data;
		}
	}

	unless ($session) {
		my $uuid = Data::UUID->new;
		$session_id = $uuid->create_str;
		$session = Contentment::Session->create({
			session_id   => $session_id,
		});
		$session->session_data($session_data = {});
		$session->update;
		$session->commit;

		Contentment::Log->debug("Creating a new SESSIONID $session_id");
	}

    $ctx->{session}{id}   = $session_id;
    $ctx->{session}{data} = $session_data;

    Contentment::Hooks->call('Contentment::Session::begin', $ctx);
}

=item Contentment::Session::save_cookie

This handles the "Contentment::Response::begin" hook and is responsible for making sure a cookie gets set on the client.

=cut

sub save_cookie {
    my $context    = shift;
    my $q          = $context->cgi;
    my $response   = $context->response;
    my $site       = $context->current_site;
    my $session_id = $context->session_id;

    my $cookie = $q->cookie(
        -name    => 'SESSIONID',
        -domain  => $site->base_url->host,
        -value   => $session_id,
        -expires => '+60m');
    push @{ $response->header->{'-cookie'} }, $cookie;
}

=item Contentment::Session::close_session

This method handles the "Contentment::Request::end" hook. It calls the "Contentment::Session::end" hook and then serializes any changes to the session data.

=cut

sub close_session {
    my $ctx = shift;

    Contentment::Hooks->call('Contentment::Session::end', $ctx);

	my ($session) = Contentment::Session->search({ 
        session_id => $ctx->session_id });

	if ($session) {
		Contentment::Log->debug("Saving session data to session ", $ctx->session_id);
		$session->session_data($ctx->session);
		$session->update;
		$session->commit;
	} else {
		Contentment::Log->error("Lost session ",$ctx->session_id," during request.");
	}

    delete $ctx->{session};
}

=back

=head2 HOOKS

This class defines and uses the following hooks:

=over

=item Contentment::Session::begin

This hook is called as soon as the session information has been added to the context. Handlers of this hook can expect a single argument: the current context object.

This hook can be used to perform additional loading or other session data modifications.

=item Contentment::Session::end

This hook is called immediately before the session information is saved. Handlers of this hook can expect a single argument: the current context object.

This hook can be used to prepare data for serialization, sanitize session data, or perform other session data modifications prior to saving.

=back

=head1 SEE ALSO

L<Contentment::Context>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1

