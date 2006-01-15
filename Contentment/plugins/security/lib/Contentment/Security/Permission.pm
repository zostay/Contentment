package Contentment::Security::Permission;

use strict;
use warnings;

our $VERSION = '0.01';

use Oryx;

use base 'Oryx::Class';

=head1 NAME

Contentment::Security::Permission - Contentment security permissions

=head1 DESCRIPTION

=cut

sub name { 'security_permission' }

our $schema = {
	attributes => [
		{
			name => 'permission_name',
			type => 'String',
		},
		{
			name => 'title',
			type => 'String',
		},
		{
			name => 'description',
			type => 'String',
		},
        {
            name => 'is_special',
            type => 'Boolean',
        },
	],
};

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
