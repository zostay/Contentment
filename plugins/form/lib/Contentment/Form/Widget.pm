package Contentment::Form::Widget;

use strict;
use warnings;

our $VERSION = '0.10';

=head1 NAME

Contentment::Form::Widget - Base class and interface for all form widgets

=head1 DESCRIPTION

The forms processing system provided by Contentment is completely extensible. Your controls may be as complicated or simple as desired. Just extend this class overriding any of the methods you need and updating objects as explained in this document.

If you need to use the existing widgets, please see the documentation for each widget (or the manual, once it's written).

=head2 WIDGET INTERFACE

If you are just planning to use widgets, here's the basic interface. The L</"WIDGET METHODS"> documentation is intended for users that need to create new kinds of widgets.

=over

=item $html = $widget-E<gt>begin

This tells the widget to render the beginning part of the widget. It basically locates the arguments needed to call the C<render_begin()> method. Use this method to render the start of a widget that contains other content.

=cut

sub _results {
    return Contentment->context->form->form->submission->results;
}

sub begin {
    my $self = shift;
    return $self->render_begin(_results());
}

=item $html = $widget-E<gt>end

This tells the widget to render the ending part. It basically locates the arguments needed to call the C<render_end()> method. Use this method to render the end tag of a widget that contains other content.

=cut

sub end {
    my $self = shift;
    return $self->render_end(_results());
}

=item $widget-E<gt>render

This is essentially a shortcut for:

  $widget->begin;
  $widget->end;

=cut

sub render {
    my $self = shift;
    my $results = _results();
    return $self->render_begin($results)
          .$self->render_end($results);
}

=back

=head2 WIDGET METHODS

This describes the methods that need to be overridden to create new widget subclasses.

=over

=item $widget = Contentment::Form::Widget-E<gt>construct(\%args)

Do not execute this method directly. Rather, use the C<define()> method of L<Contentment::Form>. See that documentation for details.

This is the constructor for your widget. It should return a blessed reference for your widget class. This is called during form definition.

The hash reference, C<%args>, passed as the only argument will be the same arguments passed to the C<define()> method of L<Contentment::Form> (minus the "class" argument). The arguments accepted by your widget can be anything you choose, but those arguments will be serialized using L<YAML>, so you may want to use some caution.

The default implementation blesses the given hash references into the given class and returns it.

=cut

sub construct {
    my $class = shift;
    my $args  = shift;
    bless $args, $class;
}

=item $id = $widget-E<gt>id

It is strongly recommended that your widget attempt to set the ID attribute to something unique and sane. This is good practice when it comes to forms and allows for some extra magic when defined. This should return the ID that will, would, or was used for the ID attribute.

The default implementation returns undef.

=cut

sub id { return undef }

=item $html = $widget-E<gt>render_begin(\%values)

This method should return the HTML needed to render the first part (or possibly all) of your widget. The hash, C<%values>, passed contains a list of values that your widget may use to pre-fill the widget. This is either a hash of defaults provided by the user or the compiled results from all the calls to the various widget C<validate()> methods.

The default implementation returns an empty string.

=cut

sub render_begin { return '' }

=item $widget-E<gt>render_end(\%values)

This method should return the HTML needed to render the end of your widget. The hash, C<%values>, passed contains a list of values that your widget may use to pre-fill the widget. This is either a hash or defaults provided by the user or the compiled results from all the calls to the various widget C<validate()> methods. (Exactly the same reference is passed to C<render_begin()>.)

The default implementation returns an empty string.

=cut

sub render_end { return '' }

=item $results = $widget-E<gt>validate($submission, \%args)

With each submission, this method is called to verify the validity of the submitted data and translate it from a raw form submission into a hash of results. It is passed the submission that is currently being processed, C<$submission>, and the raw values given from the HTTP submission in C<%args>.

If the data in C<%args> is valid, it should return a reference to a hash containing the key value pairs it will contribute to the validated results. It should B<not> modify the submission directly. On failure, it should throw a C<Contentment::ValidationException> when the widget values are invalid. Use the "results" field of the exception to place the partially validated results. This can allow the user to see and correct the entry and make another submission.

The default implementation always returns an empty hash reference.

=cut

sub validate { return {} }

=back

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
