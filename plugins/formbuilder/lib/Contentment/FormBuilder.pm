package Contentment::FormBuilder;

use strict;
use warnings;

our $VERSION = '0.01';

use IO::NestedCapture 'capture_in_out';

=head1 NAME

Contentment::FormBuilder - Implementation for a CGI::FormBuilder::Template engine

=head1 DESCRIPTION

Don't use this module directly. See L<Contentment::Form> instead.

=cut

sub new {
    my $class = shift;
    my $path  = shift;

    bless { path => $path, }, $class;
}

# The start of this code was taken from Nathan Wiger's render code in
# CGI::FormBuilder::Template::TT2 3.02:
#
#   http://search.cpan.org/src/NWIGER/CGI-FormBuilder-3.0202/lib/CGI/FormBuilder/Template/TT2.pm
#
sub render {
    my $self = shift;
    my $form = shift;

    my %tmplvar = $form->tmpl_param;

    # Template Toolkit can access complex data pretty much unaided
    for my $field ($form->field) {

        # Extract value since used often
        my @value = $field->tag_value;

        # Create a struct for each field
        $tmplvar{field}{"$field"} = {
             %$field,
             field   => $field->tag,
             value   => $value[0],
             values  => \@value,
             options => [$field->options],
             label   => $field->label,
             type    => $field->type,
             comment => $field->comment,
        };
        $tmplvar{field}{"$field"}{error} = $field->error;
    }

    # must generate JS first because it affects the others
    $tmplvar{'jshead'} = $form->script;
    $tmplvar{'title'}  = $form->title;
    $tmplvar{'start'}  = $form->start . $form->statetags . $form->keepextras;
    $tmplvar{'submit'} = $form->submit;
    $tmplvar{'reset'}  = $form->reset;
    $tmplvar{'end'}    = $form->end;
    $tmplvar{'invalid'}= $form->invalid;
    $tmplvar{'fields'} = [ map $tmplvar{field}{$_}, $form->field ];

    my $generator = Contentment::Response->resolve($self->{path});

    capture_in_out {
        $generator->generate(
            form     => \%tmplvar,
            form_ref => $form,
        );
    };

    my $fh = IO::NestedCapture->get_last_out;
    return join '', <$fh>;
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
