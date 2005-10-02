package Contentment::MicroMason;

use strict;
use warnings;

our $VERSION = '0.01';

use Contentment::Response;
use IO::NestedCapture 'capture_in_out';

=head1 NAME

Contentment::MicroMason - Mixin to make Text::MicroMason cooperate with Contentment

=head1 DESCRIPTION

This is a mixin for L<Text::MicroMason> that causes includes to be handled in the Contentment way rather than the normal way MicroMason normally does things.

=cut

sub assembler_rules {
	my $self = shift;

	return (
		$self->NEXT('assembler_rules'),
		file_token => 'perl OUT( Contentment::Response->resolve(do { TOKEN })->generate );',
	);
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
