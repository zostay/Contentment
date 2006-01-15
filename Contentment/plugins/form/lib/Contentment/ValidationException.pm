package Contentment::ValidationException;

use strict;
use warnings;

our $VERSION = '0.02';

use Contentment::Exception;

use Exception::Class
    'Contentment::ValidationException' => {
        fields => [ 'results' ],
    };

=head1 NAME

Contentment::ValidationException - Exception thrown during widget validation

=head1 SYNOPSIS

  use Contentment::ValidationException;

  Contentment::ValidationException->throw(
      message => 'Entry for username is invalid. Must contain only letters.',
      results => {
          username => '@#$%^&!',
      },
  );

=head1 DESCRIPTION

Throw this exception during validation when there are errors. The "results" field of the exception should be used to store any partially parsed results that can be used to restore the control to the value the user gave, but must fix.

=cut

sub new {
    my $class = shift;
    my %args  = @_;

    if (!defined $args{results}) {
        $args{results} = {};
    }

    return $class->SUPER::new(%args);
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
