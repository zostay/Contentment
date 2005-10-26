package Contentment::Form;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Class::Singleton';

use CGI::FormBuilder;
use Contentment::FormBuilder;

=head1 NAME

Contentment::Form - A plugin to use FormBuilder forms in Contentment

=head1 SYNOPSIS

  my @fields = qw( first_name last_name email phone );

  my $form = Contentment::Form->new_form(
      fields   => \@fields,
      tempalte => '/myforms/this-form-template.tt2',
  );

  if ($form->submitted && $form->validate) {
      $form->comfirm;
  } 
  else {
      $form->render;
  }

=head1 DESCRIPTION

This class provides a factory object for creating Contentment compatible L<CGI::FormBuilder> forms.

This plugin should be used instead of using L<CGI::FormBuilder> directly. This factory will configure the system so that templates will be loaded by the resolver and run as generators with the form's fields as input arguments.

=head2 METHODS

=over

=item $factory = Contentment::Form-E<gt>instance

Retrieve an instance of the form factory.

=item $form = Contentment::Form-E<gt>new_form(%args)

This method constructs a L<CGI::FormBuilder> object conforming to the Contentment way of doing things.  See L<CGI::FormBuilder> for full details on the arguments to pass.

The following arguments are given special handling:

=over

=item method

Normally, L<CGI::FormBuilder> defaults to "GET". The default here is "POST".

=item params

Anything specified to this parameter will be ignored. Don't use it.

=item template

The C<template> argument will be handled specially using the resolver system built-in to L<Contentment::Response> to fetch a generator and call that generator.

Do not pass a hash reference to this argument, but just the path to the template you wish to use.

At some point in the future, this will have a default variable into the themes system so that forms can be themed generically.

=back

=cut

sub new_form {
    my $self = shift->instance;
    my %args = @_;

    defined $args{method}
        or $args{method} = 'POST';

    $args{params} = Contentment::Request->cgi;
    $args{action} = undef;

    defined $args{template}
        and $args{template} = Contentment::FormBuilder->new($args{template});

    return CGI::FormBuilder->new(%args);
}

=head1 SEE ALSO

L<CGI::FormBuilder>, L<Contentment::Response>

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
