package Contentment::Security::DBI;

use strict;
use warnings;

use Contentment::SPOPS;
use SPOPS::Initialize;

my %spops = (
	user => {
		class           => 'Contentment::Security::DBI::User',
		isa             => [ qw/ Contentment::SPOPS / ],
		rules_from      => [ qw/ SPOPSx::Tool::HashField / ],
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
		hash_fields     => [ 'user_data' ],
		no_insert       => [ qw/ user_id ctime mtime dtime lastlog / ],
		no_update       => [ qw/ user_id ctime / ],
		links_to        => { 'Contentment::Security::DBI::Group' => 'group_user' },
		fetch_by        => [ qw/ username email / ],
	},

	group => {
		class           => 'Contentment::Security::DBI::Group',
		isa             => [ qw/ Contentment::SPOPS / ],
		rules_from      => [ qw/ SPOPSx::Tool::HashField / ],
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
		hash_fields     => [ 'group_data' ],
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

sub fetch_user {
	my ($class, $username) = @_;

	return Contentment::Security::DBI::User->fetch_by_username($username);
}

sub fetch_group {
	my ($class, $groupname) = @_;

	return Contentment::Security::DBI::Group->fetch_by_groupname($groupname);
}

sub fetch_all_users {
	return Contentment::Security::DBI::User->fetch_group;
}

sub fetch_all_groups {
	return Contentment::Security::DBI::Group->fetch_group;
}

1
