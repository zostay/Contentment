package Contentment::SPOPS;

use strict;
use warnings;

our $VERSION = '0.01';

use Contentment;
use DBI;
use Log::Log4perl;
use SPOPS::Secure qw/ :level :scope /;
use SQL::Translator;
use UNIVERSAL;

my $log = Log::Log4perl->get_logger("Contentment::SPOPS");

use base qw/ SPOPS::Secure SPOPS::DBI /;

use overload '""' => sub { my $self = shift; $self->id || $self; };

my $DB;
sub global_datasource_handle {
	unless (ref $DB) {
		$log->warn("creating a new connection to database");
		my $conf = Contentment::configuration;

		$DB = DBI->connect(
			$conf->{dbi_dsn}, 
			$conf->{dbi_user}, $conf->{dbi_pass}, 
			$conf->{dbi_opt}
		) || die "Cannot connect! $DBI::errstr";
	}

	return $DB;
}

sub _create_table {
	my ($class, $format, $table_name, $sql) = @_;

	my $dbh = global_datasource_handle;
	unless (grep m/`?$table_name`?/, $dbh->tables(undef, undef, $table_name)) {
		$log->warn("Table $table_name does not exist, will attempt to create");
		my $conf = Contentment::configuration;

		my $output;
		if ($format ne $conf->{sql_type}) {
			$log->debug("Format is '$format', sql_type is '$conf->{sql_type}'");
			my $t = SQL::Translator->new;
			$t->parser($format);
			$t->producer($conf->{sql_type});
			$output = $t->translate(\$sql)
				or die "Translator error: ", $t->error; 
		} else {
			$output = $sql;
		}
		$log->warn("Creating table $table_name: '$output'");

		$dbh->do($output);
	} else {
		$log->info("Table $table_name already exists");
	}
}

sub check_create {
	my ($self, $p) = @_;

	if ( $self->is_superuser || $self->is_supergroup) {
		return 1;
	} elsif ( $self->CONFIG->{can_create} ) {
		return $self->CONFIG->{can_create}->($p);
	} else {
		return $self->can_create($p);
	}
}

sub can_create { 
	my ($self, $p) = @_;

	my $ok = $p->{security_level} || 0;

	unless ( $ok ) {
		require Contentment::Security;
		my $perms = Contentment::Security::Permission->fetch_by_class( ref $self || $self );

		my $user   = $self->global_current_user;
		my $groups = $self->global_current_group || [];

		if ( defined $perms ) {
			PERM: for my $perm ( @$perms ) {
				next if $perm->{object_id}; # perms with IDs are NA to create
				next unless $perm->{capability_name} eq 'create';
				next if $perm->{scope} eq 'u' && !defined $user;
				next if $perm->{scope} eq 'g' && !@$groups;

				if ( $perm->{scope} eq 'u' && $perm->{scope_id} eq $user->id ) {
					$ok = 1;
					last PERM;
				} elsif ( $perm->{scope} eq 'g' ) {
					for my $group ( @$groups ) {
						if ( $perm->{scope_id} eq $group->id ) {
							$ok = 1;
							last PERM;
						}
					}
				} else {
					$ok = 1;
					last PERM;
				}
			}
		}	
	}

	return $ok; 
}

sub check_action_security {
	my ($self, $p) = @_;

	if ( $p->{is_add} && $self->check_create($p) ) {
		return SEC_LEVEL_WRITE;
	} elsif ( !$p->{is_add} ) {
		return $self->SUPER::check_action_security($p);
	} else {
		return SEC_LEVEL_NONE;
	}
}

sub get_security {
	my ($self, $p) = @_;

	my $level = SEC_LEVEL_NONE;

	# TODO This could be made more efficient by selecting just records with
	# object_id == 0 or object_id = self.id
	require Contentment::Security;
	my $perms = Contentment::Security::Permission->fetch_by_class( ref $self || $self );

	my $user   = $self->global_current_user;
	my $groups = $self->global_current_group || [];

	if ( defined $perms ) {
		PERM: for my $perm ( @$perms ) {
			next if $perm->{object_id} ne '0' and $perm->{object_id} ne $self->id;
			next unless $perm->{capability_name} =~ /^(?:read|write)$/;
			next if $perm->{scope} eq 'u' && !defined $user;
			next if $perm->{scope} eq 'g' && !@$groups;

			if ( $perm->{scope} eq 'u' && $perm->{scope_id} eq $user->id ) {
				$level = SEC_LEVEL_WRITE if $perm->{capability_name} eq 'write';
				$level = SEC_LEVEL_READ;
				last PERM;
			} elsif ( $perm->{scope} eq 'g' ) {
				for my $group ( @$groups ) {
					if ( $perm->{scope_id} eq $group->id ) {
						$level = SEC_LEVEL_WRITE if $perm->{capability_name} eq 'write';
						$level = SEC_LEVEL_READ;
						last PERM;
					}
				}
			} else {
				$level = SEC_LEVEL_WRITE if $perm->{capability_name} eq 'write';
				$level = SEC_LEVEL_READ;
				last PERM;
			}
		}
	}

	return { SEC_LEVEL_WORLD() => $level }; 
}

sub is_superuser {
	my $conf = Contentment::configuration;
	my $sec = $conf->{security_module};

	if ( UNIVERSAL::can($sec, "is_superuser") ) {
		return $sec->is_superuser;
	} else {
		return undef;
	}
}

sub is_supergroup {
	my $conf = Contentment::configuration;
	my $sec = $conf->{security_module};

	if ( UNIVERSAL::can($sec, "is_supergroup") ) {
		return $sec->is_supergroup;
	} else {
		return undef;
	}
}

sub global_current_user {
	defined $Contentment::context or return undef;
	my $session = $Contentment::context->session or return undef;
	my $session_data = $session->{session_data} or return undef;
	my $user = $session_data->{current_user} or return undef;
	return $user;
}

sub global_current_group {
	defined $Contentment::context or return undef;
	my $session = $Contentment::context->session or return undef;
	my $session_data = $session->{session_data} or return undef;
	my $user = $session_data->{current_user} or return undef;
	defined $user and return $user->group;
	return undef;
}

1
