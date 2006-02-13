package Contentment::Oryx;

use strict;
use warnings;

our $VERSION = '0.03';

use Contentment;
use Oryx;

use base 'Oryx::Schema';

my $init = Contentment->global_configuration;
our $storage = Oryx->connect($init->{oryx_connection}, 'Contentment::Oryx');

sub Contentment::Context::storage {
    return $storage;
}

1;
__END__

=head1 NAME

Contentment::Oryx - Oryx adapter for Contentment

=head1 SYNOPSIS

  my $storage = $context->storage;

=head1 DESCRIPTION

This is a very simple class for initiating a connection to the primary back-end utilized by the database routines of Contentment. The only method of value provided by this class is the <storage()> method added to the context and even that is only useful in unusual circumstances.

The C<storage()> method of the context should return something valid very early in the request (as soon as the plugin is loaded). Any plugin depending on this plugin should be able to use this method at any time.

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
