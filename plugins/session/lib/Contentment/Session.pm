package Contentment::Session;

use strict;
use warnings;

our $VERSION = '0.07';

use Contentment;
use Data::UUID;
use YAML;

use base 'Contentment::DBI';

=head1 NAME

Contentment::Session - Session management for Contentment

=head1 DESCRIPTION

This is a session management module specifically designed for Contentment.

=cut

__PACKAGE__->table('session');
__PACKAGE__->columns(Primary => 'session_id');
__PACKAGE__->columns(Essential => qw/ session_id session_data /);

__PACKAGE__->column_definitions([
	[ session_id   => 'varchar(36)', 'not null' ],
	[ session_data => 'text', 'null' ],
]);

sub install {
	__PACKAGE__->create_table;
}

sub remove {
	__PACKAGE__->drop_table;
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
		$session = Contentment::Session->retrieve($session_id);
		if ($session) {
			Contentment::Log->debug("Reusing existing SESSIONID $session_id");
			$session_data = Load($session->session_data);
		}
	}

	unless ($session) {
		my $uuid = Data::UUID->new;
		$session_id = $uuid->create_str;
		Contentment::Session->create({
			session_id   => $session_id,
			session_data => Dump({}),
		});
		$session_data = {};

		Contentment::Log->debug("Creating a new SESSIONID $session_id");
	}

	if ($q) {
		my $cookie = $q->cookie(
			-name    => 'SESSIONID',
			-value   => $session_id,
			-expires => '60m');
		Contentment::Response->header->{'-cookie'} = $cookie;
	}
}

sub close_session {
	my $session = Contentment::Session->retrieve($session_id);

	if ($session) {
		Contentment::Log->debug("Saving session data to session $session_id");
		$session->session_data(Dump($session_data));
		$session->update;
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

