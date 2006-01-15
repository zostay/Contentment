package Contentment::Security::Profile::Scratch;

use strict;
use warnings;

our $VERSION = 0.07;

use base 'Class::Accessor';

=head1 NAME

Contentment::Security::Profile::Scratch - profile info that exists now and is gone later

=head1 DESCRIPTION

This class defines a profile implementation (see L<Contentment::Security::Profile> for the interface) that can be stored in a cookie to provide a small amount of persistence. (Handy for remembering names and web sites for the semi-anonymous.)

=cut

__PACKAGE__->mk_accessors(qw(
    username
    full_name
    email_address
    web_site
    information
    preferences
));

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->username('Anonymous') unless $self->username;
    $self->information({})      unless $self->information;
    $self->preferences({})      unless $self->preferences;
    return $self;
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
