package Contentment::Security::Profile::Persistent;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Oryx::Class';

=head1 NAME

Contentment::Security::Profile::Persistent - profile info that persists

=head1 DESCRIPTION

This class defines a profile implementation (see L<Contentment::Security::Profile> for the interface) that is stored in the L<Oryx> storage (see L<Contentment::Oryx>).

=cut

sub name { 'security_profile' }

our $schema = {
    attributes => [
        {
            name => 'username',
            type => 'String',
        },
        {
            name => 'password',
            type => 'String',
        },
        {
            name => 'full_name',
            type => 'String',
        },
        {
            name => 'email_address',
            type => 'String',
        },
        {
            name => 'web_site',
            type => 'String',
        },
        {
            name => 'information',
            type => 'Complex',
        },
        {
            name => 'preferences',
            type => 'Complex',
        },
    ],
    associations => [
        {
            role  => 'roles',
            type  => 'Array',
            class => 'Contentment::Security::Role',
        },
    ],
};

=cut

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
