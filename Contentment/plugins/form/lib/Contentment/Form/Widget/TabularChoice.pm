package Contentment::Form::Widget::TabularChoice;

use strict;
use warnings;

our $VERSION = 0.08;

use base 'Contentment::Form::Widget';

use List::MoreUtils qw( any );
use Params::Validate qw( validate_with :types );

=head1 NAME

Contentment::Form::Widget::TabularChoice - A list of options in tabular form

=head1 SYNOPSIS

  my $template = <<'END_OF_TEMPLATE';
  [% form.start %]
  [% form.widgets.choices.render %]
  [% form.end %]
  END_OF_TEMPLATE

  my $form = Contentment::Form->define({
      # ...
      widgets => {
          choices => {
              name    => 'choices',
              class   => 'TabularChoice',
              heading => [ '', qw( Title Description ) ],
              options => [
                  [ 'first_value'  => 'First Value', 'It is the first value!' ],
                  [ 'second_value' => 'Second Value','And the second one.' ],
                  [ 'third_value'  => 'Third Value', 'And a third.' ],
              ],
          },
      },
      # ...
  });

=head1 DESCRIPTION

This widget provides a table of choices in your form. Each row will contain a checkbox or a radio button and zero or more columns of additional information. This control provides a validator that makes sure that the options given are match the widget configuration.

The C<render()> method is the preferred way to rendering this control.

=head2 CONSTRUCTION

The widget constructor accepts the following options:

=over

=item name (required)

This is the name of the control.

=item options (must be present unless "options_sub" is present)

Either this parameter or "options_sub" must be given for every tabular choice control.

This option should be given as an array of row arrays. Each row array's first element is the value that the button on that row should have when checked. (I.e., the first column is the value regardless of the setting of "button_column".) The rest of the elements are the values that should be shown in the other columns of the table. Each row array should have the same length.

=item options_sub (must be present unless "options" is present)

Either this parameter or "options" must be given for every tabular choice control.

This option should be given as a string naming the fully-qualified name of a function that the control may call to fetch the options. The return value of the subroutine should return an array of row arrays as described under the "options" parameter.

The subroutine will be passed no parameters. This may change in the future, but I can't think what would be feasible/useful to pass at both render and validation time.

=item required (optional, defaults to "0")

This is a boolean option that decides if the user must make a selection on this control.

Normally, with radio buttons once an option is selected, it cannot be deselected. Therefore, if you set the "multiple" to false, but want a user to be able to choose an undefined value, you may add an option with value "". 

This means that you cannot specify the empty string as a proper value for your form.

=item multiple (optional, defaults to "1")

This option is a boolean that decides whether or not the buttons should be checkboxes or radio buttons. With a true value, checkboxes are used. With a false value, radio buttons are used.

=item button_column (optional, defaults to "0")

This specifies which column should be used to hold the button. The first column is "0". 

You may use negative numbers to place the control column based upon the position of the last column. That is, "-1" is the last column, "-2" is the next to last column, etc.

=item heading (optional)

This specifies the headings to give each column of the table. If this option is not given, there will be no headings.

The option should be given as a reference to an array. The first index, "0", of the headings is always the heading for the button column, regardless of the setting for "button_column". This array must have the same number of elements as each index of the "options" array or results of the method called as the "option_sub" option.

=back

=head2 VALIDATION

The validation for this control works as follows:

=over

=item 1.

If the "required" option is set to true, then something must be set. If nothing is set, an error occurs.

=item 2.

If the "multiple" option is set to to false, then no more than one option may be set. If multiple options are set, an error occurs.

=item 3.

For every option checked with the form, the value of that option must exist in the list of values in the "options" setting or must exist in the list returned by "options_sub".

=back

If validation passes all of these tests, then a value named according to the "name" option will be added to the results. If "multiple" is set, this option will be an array reference containing zero or more elements. If "multiple" is not set, it will be a scalar or C<undef>. Obviously, if "required" is set, then the array reference would contain one or more elements and the scalar couldn't be C<undef>.

Any query parameter set to an empty string will be considered as unset. This allows for controls with "multiple" set to false and "required" set to false to be deselected if an option with an empty string value is supplied. This also means that the empty string is ignored as an option value.

=cut

sub construct {
    my $class = shift;

    my %p = validate_with(
        params => \@_,
        spec => {
            name => {
                type => SCALAR,
            },
            options => {
                type    => ARRAYREF,
                default => undef,
            },
            options_sub => {
                type    => SCALAR,
                regex   => qr/^[\w:]+$/,
                default => undef,
            },
            required => {
                type    => BOOLEAN,
                default => 0,
            },
            multiple => {
                type    => BOOLEAN,
                default => 1,
            },
            button_column => {
                type    => SCALAR,
                regex   => qr/^-?\d+$/,
                default => 0,
            },
            heading => {
                type    => ARRAYREF,
                default => undef,
            },
        },
    );

    # Make sure one of them is given
    unless (defined($p{options}) xor defined($p{options_sub})) {
        Contentment::Exception->throw(
            message => 'TabularChoice widget constructor requires either '
                      .'the "options" or "options_sub" option to be given, '
                      .'but not both.'
        );
    }
    
    my $self = bless \%p, $class;

    # Pre-rearrange the "heading", if given
    if (defined $p{heading}) {
        my $button_column = $self->_button_column(scalar(@{ $p{heading} }));
        my $button_heading = shift @{ $p{heading} };
        splice @{ $p{heading} }, $button_column, 0, $button_heading;
    }

    return $self;
}

sub _button_column {
    my $self = shift;
    my $size = shift;
    return $self->{button_column} < 0 ? $size + $self->{button_column}
                                      : $self->{button_column};
}

sub id {
    my $self = shift;
    return $self->{name};
}

sub render_begin {
    my $self   = shift;
    my $values = shift;

    my $html;
   
    # Start the table
    $html  = qq(<table id="$self->{name}" class="tabular-choice-widget">\n);

    # Add the heading
    if (defined $self->{heading}) {
        $html .= qq(<tr>);
        for my $heading (@{ $self->{heading} }) {
            $html .= qq(<th>$heading</th>);
        }
        $html .= qq(</tr>\n);
    }

    my @options;

    # Load the options from the "options" parameter
    if (defined $self->{options}) {
        @options = @{ $self->{options} };
    }

    # Load the options from the "options_sub" parameter
    elsif (defined $self->{options_sub}) {
        no strict 'refs';
        @options = @{ $self->{options_sub}->() };
    }

    # Bad stuff.
    else {
        Contentment::Exception->throw(
            message => 'Unexpected else reached.',
            details => 'Neither "options" nor "options_sub" are given.',
        );
    }

    # Skip to the end if there aren't any options
    if (@options) {

        # Figure out which column is the button_column
        my $button_column = $self->_button_column(scalar(@{ $options[0] }));

        # Rip out the values from each of the options for transformation
        my @values = map { shift @$_ } @options;

        # Make all the values themselves into labels so that they become clicky
        # in good browsers.
        for my $i (0 .. $#options) {
            for my $column (@{ $options[$i] }) {
                $column = qq(<label for="$self->{name}-$i">$column</label>);
            }
        }

        # Load each row with the button
        for my $i (0 .. $#options) {
            my $row   = $options[$i];
            my $value = shift @values;
            
            # Create the button as needed: make sure it has the right ID and
            # that it is a checkbox or radio button as per our settings.
            my $button = q(<input type=");
            $button .= $self->{multiple} ? 'checkbox' : 'radio';
            $button .= qq(" name="$self->{name}" value="$value" );
            $button .= qq(id="$self->{name}-$i" );

            # Check it if it should be selected
            if ($self->{multiple} 
            && any { $_ eq $value } @{ $values->{ $self->{name} } }) {
                $button .= qq(checked="checked" );
            }

            # Check it if it should be selected
            elsif (!$self->{multiple} && $value eq $values->{ $self->{name} }) {
                $button .= qq(checked="checked" );
            }

            # eles { $button .= qq(); }
            
            # Close up the tag
            $button .= qq(/>);

            # Insert the button into the correct column
            splice @$row, $button_column, 0, $button;

            # Output the row
            $html .= qq(<tr>);
            for my $column (@$row) {
                $html .= qq(<td>$column</td>);
            }
            $html .= qq(</tr>\n);
        }
    }

    # Close out the table and return the widget text
    $html .= qq(</table>);
    return $html;
}

sub validate {
    my $self       = shift;
    my $submission = shift;
    my $values     = shift;
    my $value      = $values->{ $self->{name} };

    # Let's first normalize the data to make it easier to work with
    if (defined $value && ref $value ne 'ARRAY') {
        $value = [ $value ];
    }
    elsif (!defined $value) {
        $value = [];
    }
    # Otherwise, value should already be an array

    # Rip out any undefs or empty strings; they don't count
    @$value = grep { defined $_ && $_ ne '' } @$value;

    # Make sure a required widget is filled
    if ($self->{required} && !@$value) {
        Contentment::ValidationException->throw(
            message => qq(The field "$self->{name}" is required.),
            # There are no results to hand back anyway
            # results => {},
        );
    }

    # Make sure there is no more than one selection when multiple is false.
    if (!$self->{multiple} && @$value > 1) {
        Contentment::ValidationException->throw(
            message => qq(The field "$self->{name}" only accepts a single )
                       .q(item.),
            # Just pick the first one and forget the rest.
            results => { $self->{name} => $value->[0] },
        );
    }

    my @options;

    # Get options from the "options" parameter
    if (defined $self->{options}) {
        @options = @{ $self->{options} };
    }

    # Get options from the "options_sub" parameter
    elsif (defined $self->{options_sub}) {
        no strict 'refs';
        @options = @{ $self->{options_sub}->() };
    }

    # Bad stuff.
    else {
        Contentment::Exception->throw(
            message => 'Unexpected else reached.',
            details => 'Neither "options" nor "options_sub" are given.',
        );
    }

    # Grab the list of possible values for our options
    my %possible_values
        = map  { $_ => 1 }
          grep { defined $_ && $_ ne '' }
          map  { $_->[0] } @options;

    # Make sure the given options are possible options
    if (my @bad_values = grep { !defined $possible_values{$_} } @$value) {
        my $results 
            = $self->{multiple}
            ? { $self->{name} => [ 
                    grep { defined $possible_values{$_} } @$value
              ] }
            : {};

        Contentment::ValidationException->throw(
            message => qq(Unexpected options for field "$self->{name}": )
                      .join(', ', @bad_values),

            # If it's not multiple, then the only value is impossible!
            results => $results,
        );
    }

    # The form field is valid. Return the values.
    my $results = $self->{multiple} ? { $self->{name} => $value }
                                    : { $self->{name} => $value->[0] };
    return $results;
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
