package Contentment::Form::Widget::Input;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Contentment::Form::Widget::Input - Submission processor for HTML input widgets.

=head1 DESCRIPTION

Processes the submission of a standard input control. This simply copies the raw submission value named for the widget to the processed variable location by the same name.

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
