package Contentment::Form::Widget::Submit;

use strict;
use warnings;

our $VERSION = '0.03';

use base 'Contentment::Form::Widget';

use Contentment::ValidationException;
use Params::Validate qw( validate_with :types );

=head1 NAME

Contentment::Form::Widget::Submit - Submit widget

=head1 SYNOPSIS

  my $form = Contentment::Form->define(
      # ...
      widgets => {
          submit => {
              value => [ qw( Up Down Left Right ) ],
              class => 'Submit',
          },
      }
      # ...
  );

=head1 DESCRIPTION

This provides a simple widget for adding submit buttons to a form. This widget performs validation to make sure that only submit labels given can be used.

The widget constructor accepts the following arguments:

=over

=item name (optional, defaults to "submit")

If not given, the name defaults to "submit".

=item value (optional, defaults to "Submit")

This may either be a scalar name of a submit button or an array of names for submit buttons. Upon submission, only the button names given will be accepted (or else a validation error will occur).

By default, the value is "Submit".

=back

=cut

sub construct {
    my $class = shift;

    my %p    = validate_with(
        params => \@_,
        spec   => {
            name => {
                type    => SCALAR | UNDEF,
                default => 'submit',
            },
            value => {
                type    => SCALAR | ARRAYREF | UNDEF,
                default => 'Submit',
            },
        },
    );

    if (!ref $p{value}) {
        $p{value} = [ $p{value} ];
    } 

    return bless \%p, $class;
}

sub id {
    my $self = shift;
    return $self->{name};
}

sub render_begin {
    my $self = shift;

    my $html;
    for my $value (@{ $self->{value} }) {
        $html .= 
            qq(<input type="submit" name="$self->{name}" id="$self->{name}" )
           .qq(value="$value"/> );
    }

    return $html;
}

sub validate {
    my $self       = shift;
    my $submission = shift;
    my $p          = shift;

    my $value = $p->{ $self->{name} };

    my %possible_values = map { $_ => 1 } @{ $self->{value} };

    if (defined $value && !$possible_values{ $value }) {
        Contentment::ValidationException->throw(
            message => qq(There is no button named "$value" on the form for )
                      .qq(field "$self->{name}".),
            # Purposely avoid setting results because it doesn't make sense in
            # this particular case.
        );
    } else {
        return { $self->{name} => $value };
    }
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
