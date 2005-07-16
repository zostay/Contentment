package Contentment::Security::DBI;

use strict;
use warnings;

use Contentment::SPOPS;
use SPOPS::Initialize;

our $VERSION = '0.02';

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
		rules_from      => [ qw/ SPOPSx::Tool::YAML / ],
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
		no_insert       => [ qw/ user_id ctime mtime dtime lastlog / ],
		no_update       => [ qw/ user_id ctime / ],
		links_to        => { 'Contentment::Security::DBI::Group' => 'group_user' },
		fetch_by        => [ qw/ username email / ],
	},

	group => {
		class           => 'Contentment::Security::DBI::Group',
		isa             => [ qw/ Contentment::SPOPS / ],
		rules_from      => [ qw/ SPOPSx::Tool::YAML / ],
		base_table      => 'group',
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
		no_insert       => [ qw/ group_id ctime mtime dtime lastlog / ],
		no_update       => [ qw/ group_id ctime / ],
		links_to        => { 'Contentment::Security::DBI::User' => 'group_user' },
		fetch_by        => [ 'groupname' ],
	},
);

SPOPS::Initialize->process({ config => \%spops });

Contentment::Security::DBI::User->_create_table('MySQL', 'user', q(
	CREATE TABLE user (
		user_id			INT(11) NOT NULL AUTO_INCREMENT,
		username		CHAR(30) NOT NULL,
		fullname		CHAR(100) NOT NULL,
		email			CHAR(150) NOT NULL,
		webpage			CHAR(150) NOT NULL,
		password		CHAR(100) NOT NULL,
		ctime			DATETIME NOT NULL DEFAULT 'now',
		mtime			DATETIME NOT NULL DEFAULT 'now',
		dtime			DATETIME NULL,
		lastlog			DATETIME NULL,
		enabled			INT(1) NOT NULL DEFAULT '1',
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

Contentment::Security::DBI::Group->_create_table('MySQL', 'group', q(
	CREATE TABLE group (
		group_id		INT(11) NOT NULL AUTO_INCREMENT,
		groupname		CHAR(30) NOT NULL,
		description		CHAR(100) NOT NULL,
		ctime			DATETIME NOT NULL DEFAULT 'now',
		mtime			DATETIME NOT NULL DEFAULT 'now',
		dtime			DATETIME NULL,
		enabled			INT(1) NOT NULL DEFAULT '1',
		group_data		TEXT NOT NULL,
		PRIMARY KEY (group_id),
		UNIQUE (groupname));
));

=head1 SECURITY MODULE METHODS

=over

=item $user = Contentment::Security::DBI-E<gt>check_login($username, $password)

Checks the databsae for a user named C<$username> and verifies that the user has the given password C<$password>. If so, the record is returned. Otherwise, this method returns C<undef>.

=cut

sub check_login {
	my ($class, $username, $password) = @_;

	my $users = Contentment::Security::DBI::User->fetch_by_username($username, { skip_security => 1 });
	return undef unless @$users;

	my $user = $users->[0];
	if ($user->{password} eq $password) {

		# allow YAML to serialize and keep users from mucking with themselves	
		my %copy = %$user; 
		delete $copy{password}; # security precaution

		$Contentment::context->session->{session_data}{current_user} = \%copy;
		return $user;
	}
	
	return undef;
}

=item $user = Contentment::Security::DBI-E<gt>fetch_user($username)

Returns the user record for the username given or C<undef>.

=cut

sub fetch_user {
	my ($class, $username) = @_;

	return Contentment::Security::DBI::User->fetch_by_username($username);
}

=item $group = Contentment::Security::DBI-E<gt>fetch_group($gropuname)

Returns the group record for the groupname given or C<undef>.

=cut

sub fetch_group {
	my ($class, $groupname) = @_;

	return Contentment::Security::DBI::Group->fetch_by_groupname($groupname);
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
