package Contentment::Security;

use strict;
use warnings;

our $VERSION = '0.01';

use Contentment::SPOPS;
use SPOPS::Initialize;

=head1 NAME

Contentment::Security - Framework for security in Contentment

=head1 TODO

This documentation should be moved somewhere else.

=head1 DESCRIPTION

This security framework is based closely upon conforming to the restrictions of the L<SPOPS::Manual::Security> framework. That's due to the fact that we general expect plugin modules to use L<SPOPS> for any database back-end. However, the framework is a little more general as it allows for both restricting access to database records (back-end) and restricting access to actual components (front-end).

=head2 FRAMEWORK

This is a framework for defining permissions. Permissions must be applied to users and groups, which are defined by another set of security objects. Contentment, as of this writing, provides a single user base implementation, L<Contentment::Security::DBI>.

Administrators and developers using Contentment may write their own implementation to suit their needs, they just need to implement the contract defined here via a Perl module. Then, they need to point the C<Contentment.conf>'s C<security_module> variable to the name of that Perl module.

=head2 CONTRACT

Your system must do the following:

=over

=item *

Must define two types of objects, groups and users. Users may belong to any number of groups and groups may contain any number of users. The actual definition and relationsihp between these is up to the implementor, so the actual relationships may be as simple or complicated as you, the plugin writer, like.

=item *

The main security module must define two methods: C<fetch_user> and C<fetch_group>. Each should accept an ID value of the object to retrieve as the only argument. Each should return the appropriate user or group object matching the ID.

=item *

The main module should also define two additional methods: C<fetch_all_users> and C<fetch_all_groups>. These should return an array reference containing all users or all groups, respectively. 

=item *

The objects returned by C<fetch_user> and C<fetch_group> must return their ID from a function named C<id>.

=item * 

The C<id> may be any valid Perl scalar number or string shorter than 256 characters.

=item *

The objects returned by C<fetch_user> must have a method named C<group>, which returns the group objects to which the user belongs in an array reference.

=item *

The objects returned by C<fetch_group> must have a method named C<user>, which returns the user objects which are members of the group in an array reference.

=back

The security module may define any additional methods or functionality it likes. The contract does not specify how users and groups are managed, only how to fetch them.

=head2 PERMISSIONS

This security module also provides the definitions of all permissions. There are four types of permissions: object permissions (L<Contentment::Security::Permission>), create permissions (L<Contentment::Security::CreatePermission>), initial object permissions (L<Contentment::Security::InitialPermission>), and URL permissions (L<Contentment::Security::URLPermissions>). These objects are all defined by L<Contentment::Security>.

=head3 Object Permissions

There are four object permission security levels that may be associated with any record or group of records: None, Summary, Read, and Write. These permissions are taken directly from L<Contentment::Manual::Security>. None means that the affected user(s) are not able to discover the existence of the matched record(s). Summary means that the affected user(s) are able discovered the matched record(s) but may not be able to read all fields. Read means that he affected user(s) are able to read the matched record(s) in their entirety. Write means that the affected user(s) are able to alter and delete the record as well as read it.

These permissions are matched agains an entire class (table) or against individual records. User permissions are applied first, then group permissions, then other permissions.

=head3 Create Permissions

Create permissions are either on or off for groups of users. A Contentlet designer may choose to use these permissions or may define their own by defining a "can_create" method (see L<Contentment::SPOPS>). If a user or group has permission to create a record, the security level is true (non-zero). Otherwise, it will be false (zero).

Matching permissions happens in the same order as object permissions: user, then group, then other.

=head3 Initial Permissions

When a user creates a record, we may assign them some initial object permissions. This is what SPOPS calls "Create Permissions," which is confusing to me, so I call them Initial permissions. These are the same set of permissions available for object permissions and the one that matches the user, group, or other user the same way as described in Object Permissions, will be used to assign new permissions added to the Object Permissions table on creation.

This may be superfluous in many cases, but it may be useful if we want to grant the creator special privileges.

=head3 URL Permissions

Totally unrelated to the record permissions discussed thus far are the URL permissions. In general, the URL permissions should be avoided if the same restrictions can be achieved through object permissions or create permissions or by developer coded custom permissions. The reason is that URL permissions only block the use of components on the front end of the Contentment system.

This is mostly meant to be useful in cases where access to components cannot be limited on the basis of database records. For example, if a component performs some action just to the file system or some other resource, but doesn't interact with the internal store, these permissions become useful.

=head2 ADVANCED USE

The use of any of these permissions directly is considered "advanced." Rather, only Contentlet component designers should regularly need to manipulate these permissions. The permissions system used is really quite complex and shouldn't be exposed to the common user unless necessity forces the issue.

=cut

my %spops = (
#	permission => {
#		class           => 'Contentment::Security::Permission',
#		isa             => [ qw/ Contentment::SPOPS SPOPS::Secure::DBI / ],
#		field           => [ qw/ 
#			sid
#			class
#			object_id
#			scope
#			scope_id
#			security_level
#		/ ],
#		id_field        => 'sid',
#		increment_field => 1,
#		no_insert       => [ qw/ sid / ],
#		skip_undef      => [ qw/ object_id scope_id / ],
#		no_update       => [ qw/ sid object_id class scope scope_id / ],
#		base_table      => 'sec_permission',
#		sql_defaults    => [ qw/ object_id scope_id / ],
#		skip_object_key => 1,
#   },
#
#	create_permission => {
#		class           => 'Contentment::Security::CreatePermission',
#		isa             => [ qw/ Contentment::SPOPS / ],
#		field           => [ qw/
#			scid
#			class
#			scope
#			scope_id
#			security_level
#		/ ],
#		id_field        => [ qw/ scid / ],
#		increment_field => 1,
#		no_insert       => [ qw/ scid / ],
#		skip_undef      => [ qw/ scope_id / ],
#		no_update       => [ qw/ scid class scope scope_id / ],
#		base_table      => 'create_permission',
#		sql_defaults    => [ qw/ scope_id / ],
#		skip_object_key => 1,
#	},
#
#	initial_permission => {
#		class			=> 'Contentment::Security::InitialPermission',
#		isa				=> [ qw/ Contentment::SPOPS / ],
#		field			=> [ qw/
#			siid
#			class
#			scope
#			scope_id
#			security_level
#		/ ],
#		id_field		=> [ qw/ siid / ],
#		increment_field	=> 1,
#		no_insert		=> [ qw/ scid / ],
#		skip_undef		=> [ qw/ scope_id / ],
#		no_update		=> [ qw/ siid class scope scope_id / ],
#		base_table		=> 'init_permission',
#		sql_defaults	=> [ qw/ scope_id / ],
#		skip_object_key => 1,
#	},
#
#	url_permission => {
#		class           => 'Contentment::Security::URLPermission',
#		isa             => [ qw/ Contentment::SPOPS / ],
#		field           => [ qw/
#			suid
#			weight
#			url_pattern
#			scope
#			scope_id
#			security_level
#		/ ],
#		id_field        => [ qw/ suid / ],
#		increment_field => 1,
#		no_insert       => [ qw/ suid / ],
#		skip_undef      => [ qw/ scope_id / ],
#		no_update       => [ qw/ suid url_pattern scope scope_id / ],
#		base_table      => 'url_permission',
#		sql_defaults    => [ qw/ weight scope_id / ],
#		skip_object_key => 1,
#	},

	permission => {
		class           => 'Contentment::Security::Permission',
		isa             => [ qw/ Contentment::SPOPS / ],
		field           => [ qw/
			pid
			class
			object_id
			scope
			scope_id
			capability_name
		/ ],
		id_field        => [ qw/ pid / ],
		increment_field => 1,
		no_insert       => [ qw/ pid / ],
		skip_undef      => [ qw/ scope_id / ],
		no_update       => [ qw/ pid url_pattern scope scope_id / ],
		base_table      => 'general_permission',
		sql_defaults    => [ qw/ scope_id / ],
		skip_object_key => 1,
		fetch_by        => [ qw/ class / ],
	},

);

SPOPS::Initialize->process({ config => \%spops });

Contentment::SPOPS->_create_table('MySQL', 'general_permission', q(
	CREATE TABLE general_permission (
		pid				INT(11) NOT NULL AUTO_INCREMENT,
		class			CHAR(60) NOT NULL,
		object_id		CHAR(150) NOT NULL DEFAULT '0',
		scope			CHAR(1) NOT NULL,
		scope_id		CHAR(20) NOT NULL DEFAULT 'world',
		capability_name CHAR(20) NOT NULL DEFAULT 'none',
		PRIMARY KEY (pid),
		UNIQUE (object_id, class, scope, scope_id, capability_name));
));
		
#Contentment::SPOPS->_create_table('MySQL', 'sec_permission', q(
#	CREATE TABLE sec_permission (
#		sid				INT(11) NOT NULL AUTO_INCREMENT,
#		class			CHAR(60) NOT NULL,
#		object_id		CHAR(150) NOT NULL DEFAULT '0',
#		scope			CHAR(1) NOT NULL,
#		scope_id		CHAR(20) NOT NULL DEFAULT 'world',
#		security_level	CHAR(1) NOT NULL,
#		PRIMARY KEY (sid),
#		UNIQUE (object_id, class, scope, scope_id));
#));
#
#Contentment::SPOPS->_create_table('MySQL', 'create_permission', q(
#	CREATE TABLE create_permission (
#		scid			INT(11) NOT NULL AUTO_INCREMENT,
#		class			CHAR(60) NOT NULL,
#		scope			CHAR(1) NOT NULL,
#		scope_id		CHAR(20) NOT NULL DEFAULT 'world',
#		security_level	CHAR(1) NOT NULL,
#		PRIMARY KEY (scid),
#		UNIQUE (class, scope, scope_id));
#));
#
#Contentment::SPOPS->_create_table('MySQL', 'init_permission', q(
#	CREATE TABLE init_permission (
#		siid			INT(11) NOT NULL AUTO_INCREMENT,
#		class			CHAR(60) NOT NULL,
#		scope			CHAR(1) NOT NULL,
#		scope_id		CHAR(20) NOT NULL DEFAULT 'world',
#		security_level	CHAR(1) NOT NULL,
#		PRIMARY KEY (siid),
#		UNIQUE (class, scope, scope_id));
#));
#
#Contentment::SPOPS->_create_table('MySQL', 'url_permission', q(
#	CREATE TABLE url_permission (
#		suid			INT(11) NOT NULL AUTO_INCREMENT,
#		weight			INT(3) NOT NULL DEFAULT '0',
#		url_pattern		CHAR(255) NOT NULL DEFAULT '.*',
#		scope			CHAR(1) NOT NULL,
#		scope_id		CHAR(20) NOT NULL DEFAULT 'world',
#		security_level	CHAR(1) NOT NULL,
#		PRIMARY KEY (suid),
#		UNIQUE (url_pattern, scope, scope_id));
#));

1
