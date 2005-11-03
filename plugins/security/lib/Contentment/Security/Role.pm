package Contentment::Security::Role;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Oryx::Class';

=head1 NAME

Contentment::Security::Role - Contentment security roles

=head1 DESCRIPTION

=cut

sub name { 'security_role' }

our $schema = {
	attributes => [
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
	associations => [
		{
			role  => 'permissions',
			class => 'Contentment::Security::Permission',
			type  => 'Array',
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
