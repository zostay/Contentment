package Contentment::Context;

use strict;
use warnings;

our $VERSION = '0.011_033';

use base 'Class::WhiteHole';

=head1 NAME

Contentment::Context - Contextual information for a Contentment request

=head1 SYNOPSIS

  package Contentment::MyModule;

  use strict;
  use warnings;

  sub Contentment::Context::my_module {
      my $ctx = shift;
      return $ctx->{my_module};
  }

  1;

=head1 DESCRIPTION

The context contains information about the application and the current request-response cycle.

If you need access to the current context object, you can always retrieve it by calling:

  my $context = Contentment->context;

See L<Contentment> for details.

=cut

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub clone {
    my $self = shift;
    return bless { %$self }, ref $self;
}

=head2 CONTEXT METHODS

To create your own context methods, just drop a method into the L<Contentment::Context> class from your own module:

  sub Contentment::Context::my_method { 1 }

It's recommended that your method throw an exception on error or if it is accessed before it becomes available or after it is no longer available. This will help during debugging.

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
