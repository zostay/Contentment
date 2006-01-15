package Contentment::Form::Widget::Text;

use strict;
use warnings;

our $VERSION = '0.03';

use base 'Contentment::Form::Widget';

use Carp;
use Params::Validate qw( validate_with :types );

=head1 NAME

Contentment::Form::Widget::Text - Textbox widget

=head1 SYNOPSIS

  my $form = Contentment::Form->define(
      # ...
      widgets => {
          username => {
              name  => 'username',
              class => 'Text',
          },
          password => {
              name  => 'password',
              class => 'Text',
          },
      },
      # ...
  );

=head1 DESCRIPTION

If you need a simple text field for something, this is your widget. It defines a simple HTML input field, which can be used to enter text or a password. The short text is validated on the server-side prior to activation. 

Eventually, this widget will also support client-side validation.

The C<render()> method is preferred for this widget since there will never be an end tag.

The widget constructor accepts the following arguments:

=over

=item name (required)

This is the name of the widget. It will be used to set the name and id field for the widget.

=item type (optional, defaults to "text")

This must be either "text" or "password". No other value is acceptable. If set to "password", the characters should be hidden while typed.

=item size (optional)

This is the displayed length of the control.

=item maxlength (optional, default is 255)

This is the maximum acceptable length for any entry into the control. If not given, it defaults to 255 characters. To unset the default set the maxlength to C<undef>. This length will be validated.

=item valid_regex (optional)

This is the only server-side validation option currently available. This allows you to specify the regular expression any submitted value must pass before being accepted.

=item valid_regex_message (optional)

This is the message to state if regex validation fails. Without it, the message is simply "invalid" (which isn't very descriptive).

=back

=cut

sub construct {
    my $class = shift;

    my %p     = validate_with(
        params => \@_,
        spec => {
            name => { 
                type => SCALAR, 
            },
            type => { 
                type    => SCALAR, 
                regex   => qr/^(?:text|password)$/ix,
                default => 'text'
            },
            size => { 
                type     => SCALAR | UNDEF, 
                regex    => qr/^\d+$/,
                default  => undef,
            },
            maxlength => { 
                type     => SCALAR | UNDEF, 
                regex    => qr/^\d+$/,
                default  => 255,
            },
            valid_regex => { 
                type      => SCALAR | UNDEF,
                default   => undef,
                callbacks => {
                    'a regular expression' => sub { ref eq 'Regexp' },
                },
            },
            valid_regex_message => {
                type     => SCALAR | UNDEF,
                depends  => [ 'valid_regex' ],
                default  => undef,
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

    my $html  = qq(<input type="$self->{type}" );
       $html .= qq(name="$self->{name}" id="$self->{name}" );
    
    # Don't send password values back across, but send the text ones.
    if ($self->{type} eq 'text' && defined $results->{ $self->{name} }) {
        my $value = $results->{ $self->{name} };
        $html .= qq(value="$value" );
    }

    $html .= qq(size="$self->{size}" )           if defined $self->{size};
    $html .= qq(maxlength="$self->{maxlength}" ) if defined $self->{maxlength};
    $html .= q(/>);

    return $html;
}

sub validate {
    my $self       = shift;
    my $submission = shift;
    my $p          = shift;

    my $value = $p->{ $self->{name} };

    if (defined $self->{maxlength} && length($value) > $self->{maxlength}) {
        Contentment::ValidationException->throw(
            message => 
                "is longer than maximum allowed length, $self->{maxlength}.",
            results => {
                $self->{name} => substr($value, 0, $self->{maxlength}),
            },
        );
    }

    if (defined $self->{valid_regex} && $value !~ /$self->{valid_regex}/) {
        Contentment::ValidationException->throw(
            message => defined $self->{valid_regex_message}
                ? $self->{valid_regex_message}
                : 'is invalid',
            results => {
                $self->{name} => $value,
            },
        );
    }

    return { $self->{name} => $value };
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
