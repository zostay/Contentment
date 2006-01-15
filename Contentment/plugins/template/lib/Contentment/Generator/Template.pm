package Contentment::Generator::Template;

use strict;
use warnings;

our $VERSION = '0.08';

use base 'Contentment::Generator::Plain';

use Contentment::Hooks;
use Contentment::Log;
use Contentment::Template;
use Params::Validate qw( validate_with :types );

=head1 NAME

Contentment::Generator::Template - Generator for Template Toolkit templates

=head1 SYNOPSIS

  my $source = <<'END_OF_TEMPLATE';
  Hello [% args.who %]!

  [% META
      title = 'Testing'
      description = 'This is a test.' 
      kind = 'text/plain' %]
  END_OF_TEMPLATE

  my $generator = Contentment::Generator::Template->new({
      source => $source,
  });

  my $title = $generator->get_property('title');

  $generator->generate({ who => 'World' });

=head1 DESCRIPTION

A generator for Template Toolkit templates.

=over

=item $generator = Contentment::Generator::Template-E<gt>new(\%args)

This constructs a template generator. It takes the following arguments:

=over

=item source (required)

This is the source template to generate from. It takes the same kinds of items as the "source" option to the constructor L<Contentment::Generator::Plain> takes.

=item properties (optional, defaults to {})

This is the set of properties to start with. These will be overridden by any properties in the source.

=item variables (optional, defaults to {})

This allows the caller to set additional "global" variables to pass into the template. Arguments are normally passed in the "args" hash. This creates additional top-level variables. For example:

  my $generator = Contentment::Tempalte::Generator->new({
      source    => 'Hello [% who %]! How is [% args.who %]?',
      variables => { who => 'Homer' },
  });

  $generator->generate({ who => 'Marge' });

outputs:

  Hello Homer! How is Marge?

Don't use the "args" key. It will be clobbered during generation.

=back

=cut

sub new {
    my $self = shift;

    my %p = validate_with(
        params => \@_,
        spec => {
            source => {
                type => GLOBREF | CODEREF | SCALAR,
            },
            properties => {
                type    => HASHREF,
                default => {},
            },
            variables => {
                type    => HASHREF,
                default => {},
            },
        },
    );

    return $self->SUPER::new(\%p);
}

=item $source = $self-E<gt>source

Returns the source. It also compiles the template the first time it's called.

=cut

sub source {
    my $self = shift;

    # Skip it if already sourced.
    return $self->SUPER::source if $self->is_sourced;

    # Otherwise, parse the template
    my $tt = Contentment::Template->new_template;
    my $source = $self->SUPER::source;
    $self->{template} = $tt->context->template(\$source);

    return $source;
}

=item $generator-E<gt>properties (EXCEPTION)

This method throws an exception stating:

  Undefined subroutine &Contentment::Generator::Template::properties called

The reason for this exception is because there is no way to retrieve a list of properties from template toolkit templates.

=cut

sub properties {
    Contentment::Exception->throw(
        message => 'Undefined subroutine &'.__PACKAGE__.'::properties called',
    );
}

=item $value = $generator-E<gt>get_property($key)

Retrieves the property value for the given key, C<$key>. This will fetch the property for the key from the proeprties set in source first, then fallback to properties set in the "properties" option to the constructor.

=cut

sub get_property {
    my $self = shift;
    my $key  = shift;

    # Parse the source
    $self->source;

    # Is the key sane?
	die "Bad key '$key'." unless $key =~ /^\w+$/;

    # Always return 1 for the "for_template_toolkit" key
	return 1 if $key eq 'for_template_toolkit';

	return 
          defined $self->{template}->$key         ? $self->{template}->$key
        :                                           $self->{properties}{$key};
}

=item $generator-E<gt>generate(\%args, \%vars)

Processes the template with the given arguments. 

The first argument, C<%args>, is passed as a hash named "args" to the template. The second argument, C<%vars>, is passed directly into the template (with any key named "args" clobbered).

=cut

sub generate {
	my $self = shift;
	my %args = @_;

    # Compile
    $self->source;

    # Process or error
    my $tt = Contentment::Template->new_template;
    my $source = $self->source;
    $tt->process(\$source, { 
        %{ $self->{variables} },
        args => \%args,
    }) or die $tt->error;

	return 1;
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::Generator::Template::match

Handles the "Contentment::VFS::generator" hook. Specifies that the "Contentment::Generator::Template" generator should be used to generate files ending in ".tt2".

=cut

sub match {
	my $file = shift;

    if ($file->basename =~ /\.tt2/) {
        my $filename = $file->basename;
        $filename =~ s/\.tt2$//;
        my $kind = Contentment::MIMETypes
            ->instance->mimeTypeOf($filename) || '';

        my %properties      = %{ $file->properties_hash };
        $properties{kind} ||= $kind;

        return Contentment::Generator::Template->new({
            source     => scalar($file->content),
            properties => \%properties,
        });
    }

    else {
        return undef;
    }
}

=back

=head1 BUGS

Currently, this generator compiles the source twice most of the time. This is due to the seemly obfuscated nature of the L<Template> Toolkit compiler. I need to unravel the innards a bit more to learn how to use a L<Template::Document> correctly.

=head1 SEE ALSO

L<Contentment::VFS>, L<Contentment::Generator::Plain>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
