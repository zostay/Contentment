package Contentment::MIMETypes;

use strict;
use warnings;

our $VERSION = '0.011_033';

use base qw( MIME::Types Class::Singleton );

=head1 NAME

Contentment::MIMETypes - Standard interface to MIME::Types

=head1 SYNOPSIS

  my $types = Contentment::MIMETypes->instance;
  my $type = $types->mimeTypeOf('foo.txt');

=head1 DESCRIPTION

This provides a common repository for MIME types used by Contentment. MIME types are a far from perfect way of determining the file type of a file. This is further aggravated by the fact that a file extension isn't really a very good way to map between MIME types and content types. 

This is why the Contentment system tries to avoid relying on MIME types directly using the concept of "file kind" instead. However, for all practical purposes file kinds tend to be the same thing as MIME Types.

This class provides a place to register the standard list of MIME types, since the default implementation doesn't contain all the types needed.

=head2 USAGE

To use this class, just call the C<instance()> method to retrieve an instance. The rest of the API is identical to L<MIME::Types>.

If you wish to customize the MIME types. You may either modify the instance returned by C<instance()> directly, or you can register with the "Contentment::MIMETypes::register" hook which is called when the singleton L<Contentment::MIMETypes> object is initially instantiated.

=cut

sub _new_instance {
    my $class = shift;
    my $self = $class->new;
    Contentment::Hooks->call('Contentment::MIMETypes::register', $self);
}

=head2 CONTEXT

This class adds the following context method:

=over

=item $mime_types = $context->mime_types

=cut

sub Contentment::Context::mime_types {
    my $ctx = shift;
    return Contentment::MIMETypes->instance;
}

=back

=head2 HOOKS

=over

=item Contentment::MIMETypes::register

This hook is called the first time the C<instance()> method is called. Each handler will be passed the freshly constructed L<MIME::Types> object for modification.

=back

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
