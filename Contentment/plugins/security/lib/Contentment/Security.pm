package Contentment::Security;

use strict;
use warnings;

our $VERSION = 0.07;

use base 'Class::Singleton';

use Contentment::Log;
use Contentment::Security::Permission;
use Contentment::Security::Profile::Persistent;
use Contentment::Security::Role;

=head1 NAME

Contentment::Security - Provides the contract for and default implementation of the Contentment security model

=head1 DESCRIPTION

The Contentment security model is an application security layer that allows for plugin replacement of the core of the system.

=head2 OVERVIEW

This module provides the front-end to the whole system. The real work of determining how security works is handled by the B<security manager> (see L<Contentment::Security::Manager> if you need to create custom security handler).

Basically, each request is assigned a B<principal> (you can think of the principal as an object representing the currrent user) by the security manager. The principal, then, provides access to the I<profile>, the I<roles>, and I<permissions>. The B<profile> contains information about the user's identity and preferences. The principal may be assigned zero or more roles. Each B<role> is a collection of permissions that are conferred to the user holding that role. A B<permission> is simply a name for some permission that can be granted or denied. A principal possesses a union of all the permissions granted by all roles.

Plugins can use this class to check the permissions available to the current principal before performing an action that requires permission. For example, you might only want to let users with the "ModerateComment" permission vote on comments:

  sub vote {
      my $self = shift;
      my $vote = shift;

      # throw an exception if they can't moderate comments
      Contentment::Security->check_permission(
          'Contentment::Plugin::Moderation::moderate_comment');

      $self->{vote} += $vote;
  }

=head2 MODULES

The important pieces of the system are handled in several different modules:

=over

=item Contentment::Security

This is the front-end to the security system that is used by most modules to determine security permissions and such.

=item L<Contentment::Security::Manager>

This is the interface that security managers must implement and provides a default implementation. 

The default implementation stores the data about users in a local database via the L<Contentment::Security::Profile::Persistent> class. Anonymous users are represented using the L<Contentment::Security::Profile::Scratch> class. It also provides the ability to login and logout using methods named C<login()> and C<logout()>.

See that class for more details.

=item L<Contentment::Security::Principal>

This object is created and returned by the security manager and provides accessors to retrieve profile information, roles, and permissions.

=item L<Contentment::Security::Profile>

This defines the interface implemented by profiles. It isn't clear that this needs to be a class, so this might just a document on what profiles are expected to do in the future.

=item L<Contentment::Security::Profile::Persistent>

This is an implementation of the profile interface that stores profile data in the database. It provides a C<password> attribute to store passwords in the database and a C<roles> where the principal's roles are loaded from.

=item L<Contentment::Security::Role>

The role object is used to associate permissions with principals. There are three special roles defined by the system (which are used by the default security manager, but don't have to be used by any other). The special roles are "Everybody", "Authenticated", and "Anonymous", which are assigned to all principals, authenticated principals, and anonymous principals, respectively.

=item L<Contentment::Security::Permission>

Permission objects represent individual permissions, which allow an associated principal to perform some operation. There is one special permission defined named "SuperUser". The C<has_permission()> method will always return a true value and C<check_permission()> will never throw an exception for any principal possessing the "SuperUser" permission. Obviously, some care should be exercised when assigning this permission.

=back

At the start of each request, the security manager that has been configured for the system determines which principal to associate with the request. The security system then loads roles associated with the principal and the permissions associated with those roles.

=head2 SECURITY FOR PLUGINS

For most developers, all that's really needed is to know which permissions have been granted for the current request. You must register your permissions before using them. Do so with the C<register_permissions()> method:

  sub install {
      Contentment::Security->register_permissions(
          'Contentment::Plugin::MyPlugin::do_something' => {
              title       => 'Do Something",
              description => "Allow person to do something.",
          },
          'Contentment::Plugin::MyPlugin::say_something' => {
              title       => "Say Something",
              description => "Allow a person to say something.",
          },
          # etc.
      );
  }


To check which permissions have been granted to the current request, just use the C<check_permission()> method:

  sub do_something {
      my $class = shift;
      my $arg   = shift;

      # check to see if the current user can do_something(). If not, this will
      # throw an exception.
      Contentment::Security->check_permission(
          'Contentment::Plugin::MyPlugin::do_something');

      $class->{do} = "something";
  }

For developers needing more fine-grained control, you can also use the C<has_permission()> method.
       
Finally, if you need to figure out what the current principal is or access the profile associated with the principal, use the L<get_principal()> method.

  my $principal = Contentment::Security->get_principal;
  print "User ",$princpal->username," has the following roles:\n";
  for my $role (@{ $princpal->roles }) {
      print " * ",$role->title,"\n";
  }

=head2 PLUGINS FOR SECURITY

If you need a specialized security manager, you'll want to see the documentation available in L<Contentment::Security::Manager>.

=head2 METHODS

Here is the documentation for each method of C<Contentment::Security>.

=over

=item $secman = Contentment::Security->security_manager

Returns the security manager implementation being used.

=cut

# Initialize Class::Singleton
sub _new_instance {
    my $class = shift;

    # Load the plugin settings
    my $settings 
        = Contentment::Setting->instance->{'Contentment::Plugin::Security'};
    my $security_manager_class 
        = $settings->{'security_manager'}
            || 'Contentment::Security::Manager';

    return bless {
        security_manager => $security_manager_class->instance,
    }, $class;
}

sub instance {
    my $proto = shift;
    my $class = ref $proto || $proto;
    return $class->SUPER::instance(@_);
}

sub security_manager {
    return shift->instance->{security_manager};
}

=item @permissions = Contentment::Security->register_permissions(%perms)

This method registers all the given permissions and returns a list of L<Contentment::Security::Permission> object created (or found) for the permissions registered.

Each permission is keyed by a name which refers to a hash reference containing two keys to strings, "title" and "description", which are used as help information about the permission. Permissions should be named using a namespace your plugin uses to guarantee uniqueness (not to mention clarifying where/how the permission applies).

See L</"SECURITY FOR PLUGINS"> for an example of this method in use.

=cut

sub register_permissions {
    my $class = shift;
   
    # This array is to store the result 
    my @perms;

    # Iterate through the permissions given for registration
    while (my ($name, $param) = splice @_, 0, 2) {
        # Check for an existing definition
        my ($perm) = Contentment::Security::Permission->search(
            permission_name => $name,
        );

        # If there's an existing definition, whine about it
        if ($perm) {
            Contentment::Log->warning("Permission named %s already exists.", [$name]);
        }

        # If not, create it
        else {
            Contentment::Log->info('Creating permission named "%s".', [$name]);
            $perm = Contentment::Security::Permission->create({
                permission_name => $name,
                title           => $param->{title},
                description     => $param->{description},
            });
        }

        # Add whatever to the result
        push @perms, $perm;
    }

    # return the result
    return @perms;
}

=item $test = Contentment::Security->has_permission($perm)

Returns a true value if the current principal has the permission named C<$perm> or false otherwise.

=cut

sub has_permission {
    my $class = shift;
    my $perm  = shift;
    my $permissions = $class->get_principal->permissions;
    return ($permissions->{$perm} || $permissions->{SuperUser}) ? 1 : q{};
}

=item Contentment::Security-E<gt>check_permission($perm)

This method uses C<has_permission()> to determine if the current request has been granted the named permission. If not, an exception is thrown.

=cut

sub check_permission {
    my $class = shift;
    my $perm  = shift;

    unless ($class->has_permission($perm)) {
        Contentment::Exception->throw(
            status  => 401,
            message => 'Access Denied.',
        );
    }
}

=item Contentment::Security-E<Gt>check_permissions(@perm)

This method uses C<has_permission()> to determine if the current request has been granted at least one of the named permissions. If not, an exception is thrown.

=cut

sub check_permissions {
    my $class = shift;

    my $permission = 1;
    for my $perm (@_) {
        $permission &= $class->has_permission($perm);
    }

    unless ($permission) {
        Contentment::Exception->throw(
            status  => 401,
            message => 'Access Denied.',
        );
    }
}

=item $principal = Contentment::Security-E<gt>get_principal

Returns the principal object associated with the current request. This is basically short for:

  $principal = Contentment::Security->security_manager->get_principal

=cut

sub get_principal {
    my $class = shift;
    return $class->security_manager->get_principal;
}

=item $principal = Contentment::Security-E<gt>lookup_principal($username)

Returns the principal object associated with the given username or C<undef> if no match is found.

=cut

sub lookup_principal {
    my $class    = shift;
    my $username = shift;
    return $class->security_manager->lookup_principal($username);
}

=back

=head1 HOOK HANDLERS

=over

=item Contentment::Security::install

Implements the "Contentment::install" hook. It is responsible for installing all of the database objects associated with the Contentment security model and default security manager.

=cut

sub install {
    # Create the tables
    my $storage = $Contentment::Oryx::storage;
    $storage->deployClass('Contentment::Security::Permission');
    $storage->deployClass('Contentment::Security::Profile::Persistent');
    $storage->deployClass('Contentment::Security::Role');

    # Create the special SuperUser permission
    my $superuser_permission
        = Contentment::Security::Permission->create({
            permission_name =>  q{SuperUser},
            title           =>  q{Super User},
            description     =>  q{Possessors of the permissions named 'SuperUser' }
                               .q{are permitted to do anything.},
            is_special      => 1,
        });
    $superuser_permission->commit;

    # Create a SuperUser role with the SuperUser permission. Notice that the
    # role is not special.
    my $superuser_role
        = Contentment::Security::Role->create({
            title       =>  'SuperUser',
            description =>  'The SuperUser can do anything. Note that it is '
                           .'the SuperUser permission rather than the role '
                           .'that grants this power.',
            is_special  => 0,
        });
    push @{ $superuser_role->permissions }, $superuser_permission;
    $superuser_role->update;
    $superuser_role->commit;

    # Create a special Everybody role.
    my $everybody_role
        = Contentment::Security::Role->create({
            title       =>  'Everybody',
            description =>  'Assign permissions to this role to give them to '
                           .'all users.',
            is_special  => 1,
        });
    $everybody_role->commit;

    # Create a special Anonymous role.
    my $anonymous_role
        = Contentment::Security::Role->create({
            title       =>  'Anonymous',
            description =>  'Assign permissions to this role to give them to '
                           .'anonymous users.',
            is_special  => 1,
        });
    $anonymous_role->commit;

    # Create a special Authenticated role.
    my $authenticated_role
        = Contentment::Security::Role->create({
            title       =>  'Authenticated',
            description =>  'Assign permissions to this role to give them to '
                           .'authenticated users.',
            is_special  => 1,
        });
    $authenticated_role->commit;

    # Create an initial user for the system.
    # XXX Um... using a generic password like this is probably bad stuff.
    my $superuser_profile
        = Contentment::Security::Profile::Persistent->create({
            username    => 'admin',
            password    => 'secret',
            full_name   => 'Site Administrator',
            information => {},
            preferences => {},
        });
    push @{ $superuser_profile->roles }, $superuser_role;
    $superuser_profile->update;
    $superuser_profile->commit;

    Contentment::Security->register_permissions(
        'Contentment::Security::Manager::login' => {
            title => 'login',
            description => 'May login.',
        },
        'Contentment::Security::Manager::manage_users' => {
            title => 'manage users',
            description => 'May create and edit user accounts.',
        },
        'Contentment::Security::Manager::assign_roles' => {
            title => 'assign roles',
            description => 'May assign user accounts roles.',
        },
        'Contentment::Security::Manager::manage_roles' => {
            title => 'manage roles',
            description => 'May create and edit roles.',
        },
    );
}

# XXX THERE MUST BE AN UPGRADE() METHOD TO PRESERVE THE "security_manager"
# SETTING.

=item Contentment::Security::begin

This handles the "Contentment::begin" hook and instantiates the security manager and installs the docs folder into the VFS.

=cut

sub begin {
    Contentment::Security->security_manager;

    my $vfs = Contentment::VFS->instance;
    my $setting = Contentment::Setting->instance;
    my $plugin_data = $setting->{'Contentment::Plugin::Security'};
    my $docs = File::Spec->catdir($plugin_data->{plugin_dir}, 'docs');
    $vfs->add_layer(-1, [ 'Real', 'root' => $docs ]);
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
