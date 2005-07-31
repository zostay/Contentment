package Contentment::Security::DBI;

use strict;
use warnings;

use Contentment::SPOPS;
use Log::Log4perl;
use Scalar::Util 'looks_like_number';
use SPOPS::Initialize;
use SPOPS::Secure qw/ :level :scope /;

our $VERSION = '0.03';

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::Security::DBI - Defines a simple, but relatively complete database security model

=head1 DESCRIPTION

This module defines the basic (and generally default) security model for Contentment. It uses a database store users and groups.

=over

=item Contentment::Security::DBI::User

As of this writing the majority of the fields listed below are ignored by the system. In particular, the dates for the object are not in use.

The users have the following fields:

=over

=item user_id

A numeric automatically assigned number (the number itself is insignificant).

=item username

The user's unique identifier. It is a string containing at most 30 characters.

=item fullname

The user's full name. It is a string containing at most 100 characters.

=item email

The user's primary email address.  It is a string containing at most 150 characters.

=item webpage

The user's web page. It is a string containing at most 150 characters.

=item password

The user's password. It is stored in plain text and is at most 100 characters long. I hope to add optional hashing or encryption in the future.

=item ctime

A field able to store the creation date of the user record.

=item mtime

A field able to store the last modified date of the user record.

=item dtime

A field able to store the deleted date of the user record. If this is non-null, then the C<enabled> field should be false.

=item lastlog

A field able to store the last login date of the user.

=item enabled

A boolean value specifying whether the account is active or not.

=item user_data

A hash reference able to store any other information to be associated with the user record.

=back

=item Contentment::Security::DBI::Group

Again, most of these fields aren't currently used by the system.

The fields of each group are:

=over

=item group_id

This is an automatically generated ID for the group.

=item groupname

This is the name of the group. This is a string and at most 30 characters long.

=item description

This is the long name of the group. This is a string and at most 100 characters long.

=item ctime

A date meant to store the creation time of the group.

=item mtime

A date meant to store the last modified time of the group.

=item dtime

A date meant to store the deletion time of the group. If non-null, the C<enabled> field should be set to true.

=item enabled

A boolean field stating whether the group is active or not.

=item group_data

A hash reference containing additional information about the group.

=back

=back

=cut

my %spops = (
	user => {
		class           => 'Contentment::Security::DBI::User',
		isa             => [ qw/ Contentment::SPOPS / ],
		rules_from      => [ qw/ SPOPSx::Tool::DateTime SPOPSx::Tool::YAML / ],
		base_table      => 'user',
		field           => [ qw/ 
			user_id
			username
			fullname
			email
			webpage
			password
			ctime
			mtime
			dtime
			lastlog
			enabled
			user_data
		/ ],
		id_field        => 'user_id',
		increment_field => 1,
		yaml_fields     => [ 'user_data' ],
		datetime_format => {
			ctime   => 'DateTime::Format::MySQL',
			mtime   => 'DateTime::Format::MySQL',
			dtime   => 'DateTime::Format::MySQL',
			lastlog => 'DateTime::Format::MySQL',
		},
		no_insert       => [ qw/ user_id dtime lastlog / ],
		no_update       => [ qw/ user_id ctime / ],
		links_to        => { 'Contentment::Security::DBI::Group' => 'group_user' },
		fetch_by        => [ qw/ username email / ],
		default_values  => { 
			enabled   => 1,
		},
	},

	group => {
		class           => 'Contentment::Security::DBI::Group',
		isa             => [ qw/ Contentment::SPOPS / ],
		rules_from      => [ qw/ SPOPSx::Tool::DateTime SPOPSx::Tool::YAML / ],
		base_table      => 'groups',
		field           => [ qw/ 
			group_id
			groupname
			description
			ctime
			mtime
			dtime
			enabled
			group_data
		/ ],
		id_field        => 'group_id',
		increment_field => 1,
		yaml_fields     => [ 'group_data' ],
		datetime_format => {
			ctime   => 'DateTime::Format::MySQL',
			mtime   => 'DateTime::Format::MySQL',
			dtime   => 'DateTime::Format::MySQL',
		},
		no_insert       => [ qw/ group_id dtime / ],
		no_update       => [ qw/ group_id ctime / ],
		links_to        => { 'Contentment::Security::DBI::User' => 'group_user' },
		fetch_by        => [ 'groupname' ],
		default_values  => {
			enabled    => 1,
		},
	},
);

SPOPS::Initialize->process({ config => \%spops });

Contentment::Security::DBI::User->_create_table('MySQL', 'user', q(
	CREATE TABLE user (
		user_id			INT(11) NOT NULL AUTO_INCREMENT,
		username		CHAR(30) NOT NULL,
		fullname		CHAR(100) NOT NULL,
		email			CHAR(150) NULL,
		webpage			CHAR(150) NULL,
		password		CHAR(100) NOT NULL,
		ctime			DATETIME NOT NULL,
		mtime			DATETIME NOT NULL,
		dtime			DATETIME NULL,
		lastlog			DATETIME NULL,
		enabled			INT(1) NOT NULL,
		user_data		TEXT NOT NULL,
		PRIMARY KEY (user_id),
		UNIQUE (username));
));

Contentment::Security::DBI::User->_create_table('MySQL', 'group_user', q(
	CREATE TABLE group_user (
		group_id		INT(11) NOT NULL,
		user_id			INT(11) NOT NULL,
		PRIMARY KEY (group_id, user_id));
));

Contentment::Security::DBI::Group->_create_table('MySQL', 'groups', q(
	CREATE TABLE groups (
		group_id		INT(11) NOT NULL AUTO_INCREMENT,
		groupname		CHAR(30) NOT NULL,
		description		CHAR(100) NOT NULL,
		ctime			DATETIME NOT NULL,
		mtime			DATETIME NOT NULL,
		dtime			DATETIME NULL,
		enabled			INT(1) NOT NULL,
		group_data		TEXT NOT NULL,
		PRIMARY KEY (group_id),
		UNIQUE (groupname));
));

sub _ug_update {
	my $self = shift;
	my $p    = shift;

	my $now = DateTime->now;

	if ($p->{is_add}) {
		$self->{ctime} = $now;
	}

	$self->{mtime} = $now;

	unless ($self->{enabled}) {
		$self->{dtime} = $now;
	}

	if ($self->isa('Contentment::Security::DBI::User')) {
		$self->{user_data}  ||= {};
	} else {
		$self->{group_data} ||= {};
	}

	return __PACKAGE__;
}

{
	package Contentment::Security::DBI::User;

	use Data::Dumper;
	use SPOPS::Secure qw/ :level :scope /;

	sub ruleset_factory {
		my ($class, $rs_table) = @_;
		unshift @{ $rs_table->{pre_save_action} }, \&Contentment::Security::DBI::_ug_update;
		return __PACKAGE__;
	}

	sub get_security {
		my ($self, $p) = @_;

		my $item;
		if (defined $p->{object_id}) {
			$item = $self->fetch($p->{object_id}, { skip_security => 1 });
		} else {
			$item = $self;
		}

		my $current_user = $self->global_current_user;

		if ($self->is_superuser || $self->is_supergroup) {
			$log->is_debug &&
				$log->debug("Current user is super, granting SEC_LEVEL_WRITE to user ", $item->id);
			return { SEC_SCOPE_WORLD() => SEC_LEVEL_WRITE };
		}

		if (defined($current_user) && $item->id == $current_user->id) {
			# it's me!
			my $default_level = $self->SUPER::get_security($p);

			$log->is_debug &&
				$log->debug("Default permissions are: ", Dumper($default_level));

			if ($default_level->{SEC_SCOPE_WORLD()} > SEC_LEVEL_READ) {
				$log->is_debug &&
					$log->debug("Current user ", $current_user->id, " is this user, but default perms give better than SEC_LEVEL_READ to user ", $item->id);
				return $default_level;
			} else {
				$log->is_debug &&
					$log->debug("Current user ", $current_user->id, " is this user, granting SEC_LEVEL_READ to user ", $item->id);
				return { SEC_SCOPE_WORLD() => SEC_LEVEL_READ };
			}
		} else {
			$log->is_debug &&
				$log->debug("Current user ",(defined($current_user)?$current_user->id:"(none)")," and this user don't match, falling back to default perms for user ", $item->id);

			return $self->SUPER::get_security($p);
		}
	}
}

{
	package Contentment::Security::DBI::Group;

	use SPOPS::Secure qw/ :level :scope /;

	sub ruleset_factory {
		my ($class, $rs_table) = @_;
		unshift @{ $rs_table->{pre_save_action} }, \&Contentment::Security::DBI::_ug_update;
		return __PACKAGE__;
	}
	
	sub get_security {
		my ($self, $p) = @_;

		my $item;
		if (defined $p->{object_id}) {
			$item = $self->fetch($p->{object_id}, { security_level => SEC_LEVEL_READ, skip_security => 1 });
		} else {
			$item = $self;
		}

		my $current_user = $self->global_current_user;

		if ($self->is_superuser || $self->is_supergroup) {
			$log->is_debug &&
				$log->debug("Current user is super, granting SEC_LEVEL_WRITE to user ", $item->id);
			return { SEC_SCOPE_WORLD() => SEC_LEVEL_WRITE };
		}

		if (defined $current_user) {
			for my $user (@{ $item->user }) {
				if ($user->id == $current_user->id) {
					# it's my group!
					my $default_level = $self->SUPER::get_security($p);

					if ($default_level->{SEC_SCOPE_WORLD()} > SEC_LEVEL_READ) {
						$log->is_debug &&
							$log->debug("Current user is in this group, but default perms give better than SEC_LEVEL_READ to group ", $item->id);
						return $default_level;
					} else {
						$log->is_debug &&
							$log->debug("Current user is in this group, granting SEC_LEVEL_READ to group ", $item->id);
						return { SEC_SCOPE_WORLD() => SEC_LEVEL_READ };
					}
				}
			}
		}

		return $self->SUPER::get_security($p);
	}
}

=head1 SECURITY MODULE METHODS

=over

=item $user = Contentment::Security::DBI-E<gt>check_login($username, $password)

Checks the databsae for a user named C<$username> and verifies that the user has the given password C<$password>. If so, the record is returned. Otherwise, this method returns C<undef>.

=cut

sub check_login {
	my ($class, $username, $password) = @_;

	$log->is_debug &&
		$log->debug("Login attempt initiated for $username");

	my $users = Contentment::Security::DBI::User->fetch_by_username(
		$username, { skip_security => 1 }
	);

	unless (@$users == 1) {
		if (@$users > 1) {
			$log->error("More than one user matches username $username!");
		} else {
			$log->is_warning &&
				$log->warning("Login attempt by $username FAILED (no such user)");
		}

		return undef;
	}

	my $user = $users->[0];
	if ($user->{password} eq $password) {
		$user->{lastlog} = DateTime->now;
		$user->save({ skip_security => 1 });

		$log->is_info &&
			$log->info("Login by $user->{username} successful on $user->{lastlog}");

		Contentment->context->session->{current_user} = $user;
		return $user;
	} else {
		$log->is_warning &&
			$log->warning("Login attempt by $user->{username} FAILED");
	
		return undef;
	}
}

=item $user = Contentment::Security::DBI-E<gt>fetch_user($username)

Returns the user record for the username given or C<undef>.

=cut

sub fetch_user {
	my ($class, $username) = @_;

	if (looks_like_number($username)) {
		return Contentment::Security::DBI::User->fetch($username);
	} else {
		return Contentment::Security::DBI::User->fetch_by_username($username);
	}
}

=item $group = Contentment::Security::DBI-E<gt>fetch_group($gropuname)

Returns the group record for the groupname given or C<undef>.

=cut

sub fetch_group {
	my ($class, $groupname) = @_;

	if (looks_like_number($groupname)) {
		return Contentment::Security::DBI::Group->fetch($groupname);
	} else {
		return Contentment::Security::DBI::Group->fetch_by_groupname($groupname);
	}
}

=item $users = Contentment::Security::DBI-E<gt>fetch_all_users

Returns an array reference containing all user records.

=cut

sub fetch_all_users {
	return Contentment::Security::DBI::User->fetch_group;
}

=item $groups = Contentment::Security::DBI-E<gt>fetch_all_groups

Returns an array reference containing all group records.

=cut

sub fetch_all_groups {
	return Contentment::Security::DBI::Group->fetch_group;
}

=back

=head1 SEE ALSO

L<Contentment::Security>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
