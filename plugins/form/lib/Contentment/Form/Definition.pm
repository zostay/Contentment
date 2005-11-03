package Contentment::Form::Definition;

use strict;
use warnings;

our $VERSION = '0.02';

use base qw/ Oryx::Class Class::Accessor /;

use Scalar::Util qw( weaken );

=head1 NAME

Contentment::Form::Definition - Persistent form definitions

=head1 DESCRIPTION

This class provides persisent storage of forms.

=cut

our $schema = {
    attributes => [ {
        name => 'form_name',
        type => 'String',
    },{
        name => 'version',
        type => 'Integer',
    },{
        name => 'action',
        type => 'String',
    },{
        name => 'method',
        type => 'String',
    },{
        name => 'enctype',
        type => 'String',
    },{
        name => 'template',
        type => 'Text',
    },{
        name => 'widget_parameters',
        type => 'Complex',
    },{
        name => 'created_on',
        type => 'DateTime',
    },{
        name => 'checked_on',
        type => 'DateTime',
    } ],
};

__PACKAGE__->mk_accessors(qw( activate widgets _defaults ));

sub submission {
    my $self       = shift;
    my $submission = shift;

    if (defined $submission) {
        $self->{submission} = $submission;
        weaken $self->{submission};
    }

    return $self->{submission};
}

=head2 METHODS

Instances of this class should not be constructed directly. Instead, use the C<define()> method of L<Contentment::Form> to return instances of this object.

These instances then provide the following methods:

=over

=item $form-E<gt>widgets

This returns a hash containing the constructed widgets. The keys are the mnemonic names passed to the "widgets" options of the C<define()> method of L<Contentment::Form>.

This should be used during rendering to fetch each widget and call the widget's C<render()> method or C<begin()>/C<end()> methods.

This method may also be used to modify the widget's settings after construction. This is useful when it a widget option may need to be set without making that setting a part of the persistent definition.

For example, if you have a select box with a list of options that is determined from the contents of a database table that changes frequently or which vary depending on the user accessing the form. You might not want to create a new revision to the form definition every single time the options change (or you may not want to make the definition store them at all). 

However, you must be careful in these situations that the form doesn't break during validation because the value set here is lost when a new request is created. In general, it's best if widgets take more responsibility for handling these kinds of situations.

=item $form-E<gt>render(\%defaults, \%vars)

This method renders the template that was defined in the form definition. You can specify initial default values for the form using the C<%defaults> hash. These have the same form as the results hash that should be generated during form valiation.

The second hash, C<%vars>, is used to pass in variables that should also be passed to the template.

=cut

sub render {
    my $self     = shift;
    my $defaults = shift || {};
    my $vars     = shift || {};

    # Use the default values as the results supplied if there are no results
    if (!keys %{ $self->submission->results }) {
        $self->submission->results($defaults);
        $self->submission->update;
        $self->submission->commit;
    }

    my %variables = %$vars;

    Contentment::Form->instance->{definition} = $variables{form} = $self;

    my $tt = Contentment::Template->new_template;
    my $template = $self->template;
    $tt->process(\$template, \%variables)
        or Contentment::Exception->throw(
               message => $tt->error(),
           );

    delete Contentment::Form->instance->{definition};

    return;
}

=back

=head2 RENDER METHODS

These methods should only be used within the render template.

=over

=item $form-E<gt>begin

This renders the start tag for the form.

=cut

sub begin {
    my $self = shift;

    # Start the form tag
    my $output = q(<form );

    # Add the encoding and method
    my $enctype = $self->enctype;
    my $method  = $self->method;
    $output .= qq(enctype="$enctype" method="$method" );

    # Add the form name and id and close
    my $name = $self->form_name;
    $output .= qq(name="$name" id="$name">);

    # Identify the form name, this is a must for anyone who wants to mechanize
    # or otherwise submit to the form without getting a submission ID first.
    # Once the form has been defined in the system, this field will allow the
    # user to create a submission ID on the fly.
    $output .= qq(\n<input type="hidden" id="${name}::__form__" );
    $output .= qq(name="__form__" value="$name"/>);

    # Identify the form submission used
    my $submission_id = $self->submission->submission_id;
    $output .= qq(\n<input type="hidden" id="${name}::__id__" );
    $output .= qq(name="__id__" value="$submission_id"/>);

    # Add the activation notice if requested
    if ($self->activate) {
        $output .= qq(\n<input type="hidden" id="${name}::__activate__" );
        $output .= qq(name="__activate__" value="1"/>);
    }

    # Return the output string to TT2
    return $output;
}

=item $form-E<gt>end

This renders the end tag for the form.

=cut

sub end {
    my $self = shift;

    # End it and return to TT2
    return qq(</form>);
}

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
