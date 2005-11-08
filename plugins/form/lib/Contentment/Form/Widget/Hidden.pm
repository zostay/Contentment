package Contentment::Form::Widget::Hidden;

use strict;
use warnings;

our $VERSION = '0.03';

use base 'Contentment::Form::Widget';

use Contentment::Exception;
use Params::Validate qw( validate_with :types );

=head1 NAME

Contentment::Form::Widget::Hidden - Purely server-side form data

=head1 SYNOPSIS

  my $form = Contentment::Form->define(
      # ...
      widgets => {
          foo => {
              name  => 'foo',
              class => 'Hidden',
          },
      },
      # ...
  );

  # There's no need to render this widget. The render methods do nothing.

=head1 DESCRIPTION

This is the anti-widget. This provides form storage without actually sending the client anything. The render methods for this widget do nothing, so you don't even need to bother calling them if you don't want to.

The constructor accepts the following arguments:

=over

=item name (required)

The name of the value to store in the form.

=item value (required)

The value to store in this field. This value cannot be modified by anything the client does making it extremely safe. Thus, no validation is really necessary. Also, this value may contain any data that can be serialized by L<YAML>.

=back

=cut

sub construct {
    my $class = shift;
    my %p = validate_with(
        params => \@_,
        spec => {
            name  => { type => SCALAR },
        },
    );

    return bless \%p, $class;
}

sub validate {
    my $self       = shift;
    my $submission = shift;
    my $values     = shift; # ignored
    
    # Our value will be taken from the previous results rather than the results
    # that are being created here.
    my $results = $submission->results;
    return { $self->{name} => $results->{ $self->{name} } };
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
