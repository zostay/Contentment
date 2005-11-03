package Conte3ntment::Security::Profile;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Contentment::Security::Profile - Contentment security profile interface

=head1 DESCRIPTION

This class documents the interface for profile classes. Profiles are used to store information particular to a user.

A profile object must define at least the following methods:

=over

=item $profile-E<gt>username

This should return a unique string username for the profile or C<undef> if no username is associated with the profile.

=item $profile-E<gt>full_name

This should return the name the user want's to be known as.

=item $profile-E<gt>email_address

This is the email address the user wishes to be identified with.

=item $profile-E<gt>web_site

This is the web site the user wishes to be identified with.

=item $profile-E<gt>information

This should return a reference to a hash that store's a user's personal information.

=item $profile-E<gt>preferences

This should return a reference to a hash that store's a user's configuration preferences.

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
