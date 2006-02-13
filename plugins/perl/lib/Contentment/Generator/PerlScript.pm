package Contentment::Generator::PerlScript;

use strict;
use warnings;

use base 'Contentment::Generator::POD';

our $VERSION = '0.16';

use Contentment::Exception;
use Params::Validate qw( validate_with :types );
#use Safe;

=head1 NAME

Contentment::Generator::PerlScript - A generator for Perl scripts

=head1 SYNOPSIS

  my $generator = Contentment::Generator::PerlScript->new({
      properties => {
          title => 'Testing',
          description => 'This is a test.',
      },
      code => sub {
          my $args = shift;
          print "Hello $args{who}!\n";
      },
  });

  my $title = $generator->get_property('title');
  my $description = $generator->get_property('description');

  $generator->generate({ who => "World" });

=head1 DESCRIPTION

This will run an external Perl script within the current interpreter (i.e., no forks).

These Perl scripts can expect a certain set of calling conventions. The Perl script is called within the same interpreter as the rest of Contentment. Basically, the script can be treated as if it were the body of a subroutine (which isn't far from the truth). Arguments are stored in C<@_> and the global variables available in Mason objects are also made available here.

=over

=item $generator = Contentment::Generator::PerlScript-E<gt>new(\%args)

This constructs a perl script generator. It takes the following arguments:

=over

=item source (required, unless "code" is given)

This is the Perl source code to generate from. This argument is required unless "code" is given. This argument accepts the same arguments as the argument of the same name in the constructor for L<Contentment::Generator::Plain>.

If this option is used, rather than "code", the generator will also search the source for metadata properties in the source. For example, if this snipped were part of the source:

  =begin meta
      title => 'Testing'
      description => 'This is a test.'
      kind => 'text/html'
  =end meta

The properties "title", "description", and "kind" would be set to the values given above. Also, the generated kind would be set to the value given by "kind". See L<Contentment::Generator::POD> for additional details.

This option may not be used if "code" is used.

=item code (required, unless "source" is given)

This is the Perl subroutine to actually execute. This by-passes the "source" option by allowing already compiled Perl code to be used and run. If this option is used, any required properties must be set using the "properties" option and the generated kind must be set using the "kind" option.

This option may not be used if "source" is used.

=item properties (optional, defaults to C<{}>)

This is the list of properties the generator should return. It defaults to having no properties. If the "source" option is used, properties within the source will override any set here.

=back

=cut

sub new {
    my $class = shift;

    my %p = validate_with(
        params => \@_,
        spec => {
            source => {
                type    => GLOBREF | CODEREF | SCALAR,
                default => undef,
            },
            code => {
                type    => CODEREF,
                default => undef,
            },
            properties => {
                type    => HASHREF,
                default => {},
            },
        },
    );
    
    # make sure that either "source" or "code" are given
    unless (defined $p{source} xor defined $p{code}) {
        Contentment::Exception->throw(
            message => 'Either "source" or "code" must be given.',
        );
    }

    # Set it so that the super-constructor doesn't whine
    $p{source} ||= ''; 

    # use the parent constructor to build it
    return $class->SUPER::new(\%p);
}

=item $value = $generator-E<gt>get_property($key)

This will cause the source to parsed if source was given. The properties within the file will override any specified in the constructor.

=cut

sub get_property {
    my $self = shift;
    my $key  = shift;

    # Parse the source if the source was given
    $self->source;

    return $self->{properties}{$key};
}

=item $result = $generator-E<gt>generate(@args)

If given as source, this method wraps the contents of the source in an eval as part of a subroutine and calls the subroutine. Otherwise, the subroutine passed to the code is executed.

The compiled subroutine or code will be executed every time this method is called.

=cut

sub generate {
	my $self = shift;

    # Parse the thing if it hasn't been parsed yet
    $self->source;

    # Execute it.
    return $self->{code}->($self, @_);
}

=item $source = $self->source

This overrides the method provided by L<Contentment::Generator::POD>. In addition to the work the superclass performs, this method also compiles the source code into Perl. This method will throw an exception if compilation fails.

=cut

sub source {
    my $self = shift;

    # Skip it if the source has been parsed or code was given.
    return $self->SUPER::source if $self->is_sourced || defined $self->{code};
    
    # Compile the Perl.
    my $code = $self->SUPER::source;
    my $path = $self->{properties}{path} || '';
    my $sub  = eval <<"END_OF_SUB";
sub {
my \$context = Contentment->context;
#line 1 $path
$code
}
END_OF_SUB

    # Die on errors
    die $@ if $@;

    # Store it and done.
    $self->{code} = $sub;

    return $code;
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::Generator::PerlScript::match

Handles the "Contentment::VFS::generator" hook for L<Contentment::Generator::PerlScript> and L<Contentment::Generator::POD>.

=cut

sub match {
	my $file = shift;

    my $package = 'Contentment::Generator';
    $package
       .= $file->basename =~ /\.pl$/       ? '::PerlScript'
        : $file->basename =~ /\.pod$|\.pm/ ? '::POD'
        :                                    '';

    if ($package =~ /^Contentment::Generator::/) {
        my $filename = $file->basename;
        $filename =~ s/\.(?:pl|pod|pm)$//;
        my $kind = Contentment::MIMETypes
            ->instance->mimeTypeOf($filename) || '';

        my %properties      = %{ $file->properties_hash };
        $properties{kind} ||= $kind;

        return $package->new({
            source     => scalar($file->content),
            properties => \%properties,
        });
    } 
    
    else {
        return undef;
    }
}

=back

=head1 SEE ALSO

L<Contentment::MIMETypes>, L<Contentment::Generator::POD>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
