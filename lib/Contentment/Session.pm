package Contentment::Session;

use strict;
use warnings;

our $VERSION = '0.03';

use Contentment;
use Log::Log4perl;
use SPOPS::Initialize;
use SPOPS::Secure qw/ :scope :level /;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::Session - Session management for Contentment

=head1 DESCRIPTION

This is a session management module specifically designed for Contentment. Don't use this module directly. Instead, use the C<session> method of L<Contentment::Context> to read and manipulate the returned hash, which will use this module implicitly.

=cut

my %spops = (
	session => {
		class             => 'Contentment::Session',
		isa               => [ qw/ SPOPS::Key::Random Contentment::SPOPS / ],
		rules_from        => [ qw/ SPOPSx::Tool::HashField / ],
		base_table        => 'session',
		field             => [ qw/ session_id session_data / ],
		id_field          => 'session_id',
		id_width          => 20,
		hash_fields       => [ 'session_data' ],
		no_insert         => [ 'session_id' ],
		no_update         => [ 'session_id' ],
	},
);

SPOPS::Initialize->process({ config => \%spops });

__PACKAGE__->_create_table('MySQL', 'session', q(
	CREATE TABLE session (
		session_id    CHAR(20) NOT NULL,
		session_data  TEXT NOT NULL,
		PRIMARY KEY (session_id));
));

sub get_security {
	my ($self, $p) = @_;

	my $item;
	if (defined $p->{object_id}) { # a single fetch() has been called, so state isn't set
		$log->is_debug &&
			$log->debug("Nested fetch of $p->{object_id} to retrieve session state.");
		$item = $self->fetch($p->{object_id}, { security_level => SEC_LEVEL_READ, skip_security => 1 });
	} else {
		$item = $self;
	}

	my $current_user = $self->global_current_user;
	my $session_user = $item->{session_data}->{current_user};

	# Commented to make the session code explicitly override session security.
#	if ( !defined $Contentment::context ) {
#		$log->is_debug &&
#			$log->debug("No context. Grant SEC_LEVEL_READ to first session ", $item->id);
#		return { SEC_SCOPE_WORLD() => SEC_LEVEL_READ };
#	}

	# Commented because I don't now if it's efficacious to allow users write
	# perms to all of their sessions.
#	if ( defined $current_user && defined $session_user && 
#			$current_user->id == $session_user->id ) {
#		$log->is_debug &&
#			$log->debug("Current user is matches session user, granting SEC_LEVEL_WRITE to session ", $item->id);
#		return { SEC_SCOPE_WORLD() => SEC_LEVEL_WRITE };
#	}

	if ( $self->is_superuser || $self->is_supergroup ) {
		$log->is_debug &&
			$log->debug("Current user is super, granting SEC_LEVEL_WRITE to session ", $item->id);
		return { SEC_SCOPE_WORLD() => SEC_LEVEL_WRITE };
	}

	if ( defined $Contentment::context && $Contentment::context->session_id eq $item->id ) {
		$log->is_debug &&
			$log->debug("The session matches the context, granting SEC_LEVEL_WRITE to session ", $item->id);
		return { SEC_SCOPE_WORLD() => SEC_LEVEL_WRITE };
	}

	return { SEC_SCOPE_WORLD() => SEC_LEVEL_NONE };
}

sub open_session {
	my $q = $Contentment::context->m->cgi_object;

	my $id = $q->cookie('SESSIONID');

	my %session;
	my $session;
	if ($id) {
		$session = Contentment::Session->fetch($id, { skip_security => 1 });
		if ($session) {
			$log->debug("Reusing existing SESSIONID $id");
			%session = %{ $session->session_data };
		}
	}

	unless ($session) {
		$session = Contentment::Session->new;
		$session->{session_data} = {};
		$session->save;

		$id = $session->id;
		$log->debug("Creating a new SESSIONID $id");
	}

	my $conf = Contentment->configuration;

	my $cookie = $q->cookie(
		-name    => 'SESSIONID',
		-value   => $id,
		-expires => $conf->{session_cookie_duration});
	$Contentment::context->r->header_out('Cookie', $cookie);
	
	$Contentment::context->session_id($id);
	$Contentment::context->session(\%session);
}

sub close_session {
	my $id = $Contentment::context->session_id;
	my $session = Contentment::Session->fetch($id, { skip_security => 1 });
	$session->{session_data} = $Contentment::context->session;
	$session->save;
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

