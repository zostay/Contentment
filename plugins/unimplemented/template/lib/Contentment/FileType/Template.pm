package Contentment::FileType::Template;

use strict;
use warnings;

our $VERSION = '0.01';

use Template;

use base 'Contentment::FileType::Other';

=head1 NAME

Contentment::FileType::Template - File type plugin utilizing Text::MicroMason

=head1 DESCRIPTION

This provides templating features via the L<Text::MicroMason> API. This gives Contentment the ability to serve files utilizin

=over

=cut

my %template;
sub template {
	my $class = shift;
	my $type  = shift;
	return $template{$type} if $template{$type};
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
