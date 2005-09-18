package Contentment::SPOPS;

use strict;
use warnings;

our $VERSION = '0.05';

use Contentment;
use Data::Dumper;
use DBI;
use Log::Log4perl;
use SPOPS::Secure qw/ :level :scope /;
use UNIVERSAL;

my $log = Log::Log4perl->get_logger("Contentment::SPOPS");

use base qw/ SPOPS::Secure SPOPS::DBI::MySQL SPOPS::DBI /;

use overload '""' => sub { my $self = shift; $self->id || $self; };

=head1 NAME

Contentment::SPOPS - This is the base class for all SPOPS DBI objects in Contentment

=head1 DESCRIPTION

All Contentment objects that use the SPOPS persistence framework are based from this object.

This class also heavily modifies the SPOPS security model. The last "S" of "SPOPS" is supposed to be for "Security," but I think their security model stinks. However, the SPOPS security model is relatively easy to replace, which is neat. Anyway, this class changes most of the way the SPOPS security model works, so if you've read L<SPOPS::Manual::Security>, most of that knowledge doesn't apply here.

=over

=item $dbh = Contentment::SPOPS::global_datasource_handle

Returns a database handle as configured in the main configuration file.

=cut

my $DB;
sub global_datasource_handle {
	unless (ref $DB) {
		$log->warn("creating a new connection to database");
		my $conf = Contentment->configuration;

		$DB = DBI->connect(
			$conf->{dbi_dsn}, 
			$conf->{dbi_user}, $conf->{dbi_pass}, 
			$conf->{dbi_opt}
		) || die "Cannot connect! $DBI::errstr";
	}

	return $DB;
}

=item $test = $obj->check_create($p)

This method is called to see if the user has permission to create instances of this object. It returns true if they may or false otherwise.

The implementation first checks to see if the current session belongs to a superuser or member of a supergroup. If so, access is immediately granted. Otherwise, it checks to see if a "C<can_create>" method is defined in the configuration and returns whatever value is defined there if it is. Finally, it will fall back on the C<can_create> method defined for the class (which should fallback to the one defined in L<Contentment::SPOPS> if one isn't defined in the subclass).

=cut

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

=item $test = $obj->can_create($p)

Do not call this method directly to check security. Use C<check_create> instead. This is used to define local creation policies.

This method checks C<Contentment::Security::Permission> to see if the current user or one of the current groups qualifies for the "C<create>" capability. If so, we return true. Otherwise, we return false.

=cut

sub can_create { 
	my ($self, $p) = @_;

	my $ok = $p->{security_level} || 0;

	unless ( $ok ) {
		require Contentment::Security;
		my $perms = Contentment::Security::Permission->fetch_by_class( ref($self) || $self, { skip_security => 1 } );

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

=item $test = $obj->check_action_security($p)

This method is overridden to hook in the C<check_create> method.

This method is called every time the user attempts to create, read, or write the object. If the action is a create action, then C<check_create> is called. Otherwise, SPOPS own C<check_action_security> is called.

=cut

sub check_action_security {
	my ($self, $p) = @_;

	if ( $p->{is_add} && $self->check_create($p) ) {
		return SEC_LEVEL_WRITE;
	} elsif ( !$p->{is_add} ) {
		return $self->SUPER::check_action_security($p);
	} else {
		if ($p->{required}) {
			$self->register_security_error({ 
				class    => (ref($self) || $self), 
				id       => ref($self) ? $self->id : $p->{id},
				level    => SEC_LEVEL_NONE,
				required => $p->{required} 
			});
		} else {
			return SEC_LEVEL_NONE;
		}
	}
}

=item $test = $obj->get_security($p)

This method is called either to check to see which permissions the user is granted to read or write a record or by SPOPS to check to see whether a given session should be granted those permissions.

This method checks to see what the maximum ability available to the current user and current groups and returns that level. The C<Contentment::Security::Permission> class is checked to see if any general permission exists to give the user the "C<read>" or "C<write>" capabilities.

=cut

sub get_security {
	my ($self, $p) = @_;

	my $level = SEC_LEVEL_NONE;

	# TODO This could be made more efficient by selecting just records with
	# object_id == 0 or object_id = self.id
	require Contentment::Security;
	my $perms = Contentment::Security::Permission->fetch_by_class( 
		ref($self) || $self, 
		{ skip_security => 1 }
	);

	$log->is_debug && defined $perms &&
		$log->debug("Found ", scalar(@$perms), " permission records for ", (ref($self) || $self));

	my $user   = $self->global_current_user;
	my $groups = $self->global_current_group({ skip_security => 1 }) || [];

	my $id = ref($self) ? $self->id : $p->{object_id};

	if ( defined $perms ) {
		PERM: for my $perm ( @$perms ) {
			$log->is_debug &&
				$log->debug("Checking against permission: ", Dumper($perm));

			next if $perm->{object_id} ne '0' and $perm->{object_id} ne $id;
			next unless $perm->{capability_name} =~ /^(?:read|write)$/;
			next if $perm->{scope} eq 'u' && !defined $user;
			next if $perm->{scope} eq 'g' && !@$groups;

			if ( $perm->{scope} eq 'u' && $perm->{scope_id} eq $user->id ) {
				$level = $perm->{capability_name} eq 'write' ? SEC_LEVEL_WRITE :
				         $perm->{capability_name} eq 'read'  ? SEC_LEVEL_READ  :
						                                       SEC_LEVEL_NONE;
				$log->is_debug &&
					$log->debug("Scope is user and scope_id $perm->{scope_id} matches current user with capability $perm->{capability_name}, so level is now $level.");
			
				last PERM;
			} elsif ( $perm->{scope} eq 'g' ) {
				for my $group ( @$groups ) {
					if ( $perm->{scope_id} eq $group->id ) {
						$level = $perm->{capability_name} eq 'write' ? SEC_LEVEL_WRITE :
								 $perm->{capability_name} eq 'read'  ? SEC_LEVEL_READ  :
																	   SEC_LEVEL_NONE;
						$log->is_debug &&
							$log->debug("Scope is group and scope_id $perm->{scope_id} matches a current group with capability $perm->{capability_name}, so level is now $level.");
			
						last PERM;
					}
				}
			} elsif ( $perm->{scope} eq 'w' ) {
				$level = $perm->{capability_name} eq 'write' ? SEC_LEVEL_WRITE :
				         $perm->{capability_name} eq 'read'  ? SEC_LEVEL_READ  :
						                                       SEC_LEVEL_NONE;
				$log->is_debug &&
					$log->debug("Scope is world with capability name $perm->{capability_name}, so level is now $level.");

				last PERM;
			} else {
				die "Unknown permission scope '$perm->{scope}'!";
			}
		}
	}

	return { SEC_SCOPE_WORLD() => $level }; 
}

=item $test = $obj->is_superuser

Checks to see if the security model set in the Contentment configuration provides a method named C<is_superuser>. If so, returns the value returned by that method. If not, returns false.

=cut

sub is_superuser {
	my $conf = Contentment->configuration;
	my $sec = $conf->{security_module};

	if ( UNIVERSAL::can($sec, "is_superuser") ) {
		return $sec->is_superuser;
	} else {
		return undef;
	}
}

=item $test = $obj->is_supergroup

Checks to see if the security model set in the Contentment configuration provides a method named C<is_supergroup>. If so, returns the value returned by that method. If not, returns false.

=cut

sub is_supergroup {
	my $conf = Contentment->configuration;
	my $sec = $conf->{security_module};

	if ( UNIVERSAL::can($sec, "is_supergroup") ) {
		return $sec->is_supergroup;
	} else {
		return undef;
	}
}

=item $user = $obj->global_current_user

Returns the object representing the current user if such an object can be found in the current session.

=cut

sub global_current_user {
	defined Contentment->context or return undef;
	my $session = Contentment->context->session or return undef;
	my $user = $session->{current_user} or return undef;
	return $user;
}

=item $groups = $obj->global_current_group

Returns the a reference to an array of objects representing the current groups if a user is defined for the current session. (I.e., If C<global_current_user> returns C<undef>, then so will this.)

=cut

sub global_current_group {
	my ($self, $p) = @_;

	defined Contentment->context or return undef;
	my $session = Contentment->context->session or return undef;
	my $user = $session->{current_user} or return undef;
	defined $user and return $user->group($p);
	return undef;
}

=back

=head1 SEE ALSO

L<SPOPS>, L<SPOPS::Manual::Security>, L<Contentment::Security>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1