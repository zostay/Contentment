package Contentment::Security::Principal;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Class::Accessor';

=head1 NAME

Contentment::Security::Principal - object for representing principals

=head1 DESCRIPTION

This generic object is used by the Contentment security system to represent principals. A principal represents the client's identity. This principal is meant to allow for "identity" to be fairly losely defined. However, each identity should have the following attributes:

=over

=item type

The type of the identity is a scalar that is useful to the security manager (see L<Contentment::Security::Manager>). It can be used when a security manager needs to identify different kinds of principals. For example, the built-in system uses two types: "authenticated" and "anonymous".

=item profile

The profile for the principal stores the real information for the principal. Some convenience methods are applied to grab this data without referring to the profile directly.

=item roles

The principal may have zero or more roles associated with it.

=item permissions

The really important aspect of the princpal is that it has zero or more permissions associated with it.

=back

=head2 METHODS

Every principal object defines the following methods:

=over

=item $type = $principal->type

Returns the principal type. Since this value could be anything useful to the security manager, it's probably best if the plugins avoid relying upon this value.

=item $profile = $principal->profile

The C<$profile> object returned will be an object implementing the interface given in L<Contentment::Security::Profile>.

=item @roles = @{ $principal->roles }

Returns a list of role objects (of type L<Contentment::Security::Role>) associated with the principal.

=item %permissions = %{ $principal->permissions }

Returns a hash of permission objects (of type L<Contentment::Security::Permission>) associated with the principal. The keys will be the string names for the permissions and the values will be the actual permission object for that permission name.

=cut

__PACKAGE__->mk_accessors(qw(
    type
    profile
    roles
    permissions
));

=item $username = $principal->username

A short-hand for:

  $username = $principal->profile->username

=cut

sub username {
    my $self = shift;
    return $self->profile->username;
}

=item $full_name = $principal->full_name

A short-hand for:

  $full_name = $principal->profile->full_name

=cut

sub full_name {
    my $self = shift;
    return $self->profile->full_name;
}

=item $email_address = $principal->email_address

A short-hand for:

  $email_address = $principal->profile->email_address

=cut

sub email_address {
    my $self = shift;
    return $self->profile->email_address;
}

=item $web_site = $principal-E<gt>web_site

A short-hand for:

  $web_site = $principal->profile->web_site

=cut

sub web_site {
    my $self = shift;
    return $self->profile->web_site;
}

=item $information = $principal-E<gt>information

A short-hand for:

  $information = $principal->profile->information

=cut

sub information {
    my $self = shift;
    return $self->profile->information;
}

=item $preferences = $principal-E<gt>preferences

A short-hand for:

  $preferences = $principal->profile->preferences

=cut

sub preferences {
    my $self = shift;
    return $self->profile->preferences;
}

=back

=head2 SECURITY MANAGER METHODS

The following methods are provided for use by security managers only. B<Only code in the security managers should muck with these. I<PERIOD.>>

=over

=item $principal = Contentment::Security::Principal->new;

Returns a blank principal object.

=item $principal->type($type)

Sets the type of the principal.

=item $principal-E<gt>profile($profile)

Sets the profile for the principal.

=item $principal-E<gt>roles(\@roles)

Sets the roles that have been associated with the profile.

=item $principal-E<gt>update_permissions

This method loads all the permissions associated with the roles set on the roles attribute.

=cut

sub update_permissions {
    my $self = shift;

    my %permissions;
    for my $role (@{ $self->roles }) {
        for my $permission (@{ $role->permissions }) {
            $permissions{$permission->permission_name} = $permission;
        }
    }

    $self->permissions(\%permissions);
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp E<lt>hanenkamp@cpan.orgE<gt>.  All 
Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut

1
