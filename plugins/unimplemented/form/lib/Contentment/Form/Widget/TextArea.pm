package Contentment::Form::Widget::TextArea;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Contentment::Form::Widget::TextArea - HTML text area widget processor

=head1 DESCRIPTION

This is really basic. Just suck up the value and spit it back out.

=cut

sub process {
	my $class      = shift;
	my $widget     = shift;
	my $submission = shift;

	my $value = $submission->{raw_vars}{$widget->{widget_name}};
	$submission->{vars}{$widget->{widget_name}} = $value;
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
