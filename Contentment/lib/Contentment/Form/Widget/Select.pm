package Contentment::Form::Widget::Select;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Contentment::Form::Widget::Select - HTML Select widget processor

=head1 DESCRIPTION

The behavior of this processor depends on whether the select box allows for multiselect or not. If it allows for multiselect, then the processed value (named after the select box widget) will be set to a reference to an array containing zero or more selected values. If it doesn't allow multiselect, this will be a scalar containing the selected value (or C<undef>).

=cut

sub process {
	my $class      = shift;
	my $widget     = shift;
	my $submission = shift;
	
	my $value = $submission->{raw_vars}{$widget->{widget_name}};
	if (defined $value && ref $value eq 'ARRAY') {
		if ($widget->{args}{multiselect}) {
			$submission->{vars}{$widget->{widget_name}} = $value;
		} elsif (@$value) {
			$submission->{vars}{$widget->{widget_name}} = $value->[0];
		}
	} else {
		if ($widget->{args}{multiselect}) {
			$submission->{vars}{$widget->{widget_name}} = [ $value ];
		} else {
			$submission->{vars}{$widget->{widget_name}} = $value;
		}
	}
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
