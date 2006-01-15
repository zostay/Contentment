package Contentment::Session;

use strict;
use warnings;

our $VERSION = 0.11;

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

sub install {
	__PACKAGE__->storage->deployClass(__PACKAGE__);
}

sub remove {
	__PACKAGE__->storage->util->dropTable(__PACKAGE__->table);
}

my $session_id;
my $session_data;

sub instance {
	return $session_data;
}
sub instance_id {
	return $session_id;
}

sub open_session {
	my $q = Contentment::Request->cgi;

	$session_id = $q->cookie('SESSIONID');

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

	if ($q) {
		my $cookie = $q->cookie(
			-name    => 'SESSIONID',
			-domain  => Contentment::Site->current_site->base_url->host,
			-value   => $session_id,
			-expires => '+60m');
		push @{ Contentment::Response->header->{'-cookie'} }, $cookie;
	}

    Contentment::Hooks->call('Contentment::Session::begin', $session_data);
}

sub close_session {
    Contentment::Hooks->call('Contentment::Session::end', $session_data);

	my ($session) = Contentment::Session->search({ session_id => $session_id });

	if ($session) {
		Contentment::Log->debug("Saving session data to session $session_id");
		$session->session_data($session_data);
		$session->update;
		$session->commit;
	} else {
		Contentment::Log->error("Lost session $session_id during request.");
	}

}

=head1 SEE ALSO

L<Contentment::Context>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1

