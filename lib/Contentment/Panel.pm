package Contentment::Panel;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Class::Accessor';

=head1 NAME

Contentment::Panel - The panel API is used to allow for multipurpose "panes" in a page

=head1 DESCRIPTION

I honestly haven't fleshed this out very far at this point, so I don't think I can say much more.

=cut

__PACKAGE__->mk_ro_accessors(qw/ url name map /);

sub new {
	my ($class, $url, $name, $map) = @_;

	return $class->SUPER::new({
		url  => $url,
		name => $name,
		map  => $map,
	});
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
