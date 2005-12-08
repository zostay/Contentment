package Contentment::Form::Widget::TextArea;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Contentment::Form::Widget';

use Params::Validate qw( validate_with :types);

=head1 NAME

Contentment::Form::Widget::TextArea - Text area widget

=head1 SYNOPSIS

  my $form = Contentment::Form->define(
      # ...
      widgets => {
          comment => {
              name  => 'comment',
              class => 'TextArea',
          },
      },
      # ...
  );

=head1 DESCRIPTION

This is a simple multiline text widget. It is planned that this widget may perform complicated validation, such as checking number of characters, number of words, etc. on both server and client side.

The C<render()> method is preferred for this widget.

The widget constructor accepts the following arguments:

=over

=item name (required)

This is the name of the widget. It will be used to set the name and id field for the widget.

=back

=cut

sub construct {
    my $class = shift;

    my %p = validate_with(
        params => \@_,
        spec => {
            name => {
                type => SCALAR,
            },
        },
    );

    return bless \%p, $class;
}

sub id {
    my $self = shift;
    return $self->{name};
}

sub render_begin {
    my $self    = shift;
    my $results = shift;

    my $html  = qq(<textarea name="$self->{name}" id="$self->{name}">);
       $html .= $results->{ $self->{name} };
       $html .= qq(</textarea>);

    return $html;
}

sub validate {
    my $self       = shift;
    my $submission = shift;
    my $p          = shift;

    return { $self->{name} => $p->{ $self->{name} } };
}

=cut

CODE

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
