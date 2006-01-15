package Contentment::Form::Widget::Label;

use strict;
use warnings;

our $VERSION = '0.03';

use base 'Contentment::Form::Widget';

use Contentment::ValidationException;
use Params::Validate qw( validate_with :types );

=head1 NAME

Contentment::Form::Widget::Label - A very simple label widget

=head1 DESCRIPTION

This class adds the C<label()> method to L<Contentment::Form::Widget>. This method can automatically generate a label for any widget that returns a proper value for the C<id()> method. It also takes the same arguments as the constructor, which can be used to set additional parameters:

  [% form.widgets.username.label(
         content = "Luser Name"
     ).render %]

You may choose to use either the C<render()> or C<begin()>/C<end()> methods to render the widget. However, if you use C<begin()>/C<end()> make sure to manually set content to an empty string:

  [% SET label = form.widgets.username.label(content = "") %]
  [% label.begin %]Luser Name[% label.end %]

This would render the same HTML as the code above, which sets the content option to "Luser Name".

The widget constructor takes the following arguments:

=over

=item for (required)

This should be either the ID of the widget this label belongs to or it may be the widget object itself the label should point to.

=item content (optional)

This label class attempts to be a little smarter with creating the displayed label name. If you pick control names that follow a simple convention, this will convert the control name into a pretty capitalized name.

For example,

  my $form = Contentment::Form->define(
      # ...
      widgets => {
          username => {
              name  => 'username', # ID will be "username"
              class => 'Text',
          },
          full_name => {
              name  => 'full_name', # ID will be "full_name"
              class => 'Text',
          },
      },
      # ...
  );

  # ...
  
renders:

  <label for="username">Username</label>
  <label for="full_name">Full Name</label>

All underscores in the ID are replaced with spaces and the string is converted to title-case.

=back

=cut

sub Contentment::Form::Widget::label {
    my $self = shift;
    my $args = shift || {};
    $args->{for} = $self;
    return __PACKAGE__->construct($args);
}

sub construct {
    my $class = shift;
    my %p = validate_with(
        params => \@_,
        spec => {
            for => {
                type => SCALAR | OBJECT,
            },
            content => {
                type    => SCALAR | UNDEF,
                default => undef,
            },
        },
    );

    # Convert the object to an ID
    if (UNIVERSAL::can($p{for}, 'id')) {
        $p{for} = $p{for}->id;
    }

    # DWIM the label title
    if (!defined $p{content}) {
        $p{content} = $p{for};
        
        # Change each _ to a " "
        $p{content} =~ s/_/ /g;

        # Change the first letter and each letter following a space to uppercase
        $p{content} =~ s/(?:\A|(?<=\s))(\w)/\u$1/g;
    }

    # Build it using the parent's constructor
    return bless \%p, $class;
}

sub id {
    my $self = shift;
    return $self->{for}."-label";
}

sub render_begin {
    my $self = shift;

    # Start the label
    my $id = $self->id;
    return qq(<label for="$self->{for}" id="$id" class="label-widget">)
             .$self->{content};
}

sub render_end {
    my $self = shift;

    # End the label
    return q(</label>);
}

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
