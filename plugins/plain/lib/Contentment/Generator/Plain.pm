package Contentment::Generator::Plain;

use strict;
use warnings;

use Cache::FileCache;
use DateTime;

our $VERSION = '0.13';

use IO::NestedCapture qw( capture_out );
use Params::Validate qw( validate_with :types );

=head1 NAME

Contentment::Generator::Plain - Generator for plain files

=head1 SYNOPSIS

  my $source = <<'END_OF_TEXT';
  This is a nice text file.

  It contains text. Very exciting.
  END_OF_TEXT

  my $generator = Contentment::Generator::Plain->new({
      kind => 'text/plain',
      properties => {
          foo => 1,
          bar => 2,
      },
      source => $source,
  });

  my $foo = $generator->get_property('foo');
  my $kind = $generator->generated_kind();

  $generator->generate;

=head1 DESCRIPTION

A generator for plain text files. Given a scalar, it will output that scalar. This package also provides file type matching features to allow this generator to operate as a fallback generator for the VFS.

=over

=item $generator = Contentment::Generator::Plain-E<gt>new(\%args)

This constructs a plain generator. It takes the following arguments:

=over

=item source (required)

This is the source text to generate from. Since the plain generator doesn't do anything to the given text, it will output whatever it is given during generation.

The source may be specified as a scalar containing the text to generate, a reference to a file handle from which to read the text to generate, or a reference to a subroutine that prints the text to generate to standard output. If given a subroutine, that subroutine will be called at most once and will not be passed any arguments.

=item properties (optional, defaults to C<{}>)

This is the list of properties the generator should return. It defaults to having no properties.

=back

=cut

use overload '""' => sub {
    my $self = shift;
    my $class = ref $self;
    my $title = $self->{properties}{title} || '';
    return "$class($title)";
};

sub new {
    my $class = shift;

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
        },
        allow_extra => 1,
    );

    return bless \%p, $class;
}

=item $source = $generator-E<gt>source

This accessor returns the source as a text string.

=cut

sub source {
    my $self = shift;

    # If cached, return immediately
    return $self->{cache} if $self->is_sourced;

    # If not cached and source is a file handle, cache the data in the file
    if (ref $self->{source} eq 'GLOB') {
        my $fh = $self->{source};
        $self->{cache} = join '', <$fh>;
    }

    # If not cached and source is a subroutine, run the subroutine, capture the
    # output and cache it
    elsif (ref $self->{source} eq 'CODE') {
        capture_out {
            $self->{source}->();
        };

        my $fh = IO::NestedCapture->get_last_out;
        $self->{cache} = join '', <$fh>;
    }

    # If not cached and source is a scalar, use it as the cache
    elsif (!ref $self->{source}) {
        $self->{cache} = $self->{source};
    }

    # Note that we've sourced the original source
    delete $self->{source};

    # Return the new cache
    return $self->{cache};
}

=item $test = $generator-E<gt>is_sourced

This method returns true of the source has already been processed. It returns false if it has not been. This is mainly useful to authors that want to subclass L<Contentment::Generator::Plain> and need to perform some processing only when sourcing.

=cut

sub is_sourced {
    my $self = shift;
    return defined $self->{cache};
}

=item $properties = $generate-E<gt>properties

=item $properties = $generate-E<gt>properties(\%properties);

The accessor returns a reference to the properties as a hash. The mutator replaces the stored properties with those stored in the hash.

=cut

sub properties {
    my $self       = shift;
    my $properties = shift;
    $self->{properties} = $properties if defined $properties;
    return $self->{properties};
}

=item $value = $generator-E<gt>get_property($key)

Always returns C<undef>. This is literally short-hand for:

  $value = $generator->properties->{$key};

=cut

sub get_property { 
    my $self = shift;
    my $key  = shift;
    return $self->properties->{$key};
}

#=item $headers = Contentment::FileType::Other-E<gt>generate_headers($file, @args)
#
#Uses the file's C<mtime> property (if set) to set the C<Last-Modified> header.
#
#=cut
#
#sub generate_headers {
#	my $class = shift;
#	my $file  = shift;
#
#	my %headers;
#
#	my $mtime = $file->get_property('mtime');
#	if ($mtime) {
#		$mtime = DateTime->from_epoch( epoch => $mtime );
#		$headers{'Last-Modified'} = sprintf("%s, %02d %s %d %s GMT",
#				$mtime->day_abbr, $mtime->day, $mtime->month_abbr,
#				$mtime->year, $mtime->hms);
#	}
#
#	return \%headers;
#}

=item $result = $generator-E<gt>generate

Uses the C<$data> argument to the constructor to print to standard output.

=cut

sub generate {
    my $self = shift;
    print $self->source;
	return 1;
}

=back

=head2 PLAIN GENERATOR GUTS

If you would like to subclass the plain generator, it exists as a blessed hash where the following keys are used: "source", "properties", and "cache". Do not access these directly, but use of the provided accessors. If you need to store additional data, don't use those keys.

If you need to define some action that is performed when the source is read (compiling templates, code, reading properties, etc.), then you should subclass the C<source()> method like this:

  sub source {
      my $self = shift;

      # Skip it if the source has already been processed.
      return $self->SUPER::source if $self->is_sourced;

      # Otherwise process it
      my $source = $self->SUPER::source;

      # do the processing....

      return $source;
  }

By following this pattern, your class can be further subclassed to perform even more processing as well.

=head2 HOOK HANDLERS

=over

=item Contentment::Generator::Plain::match

Used to handle the "Contentment::VFS::generator" hook. Always returns a L<Contentment::Generator::Plain> object for the file.

=cut

sub match { 
    my $file = shift;
    
    my %properties      = %{ $file->properties_hash };
    $properties{kind} ||= Contentment::MIMETypes
        ->instance->mimeTypeOf($file->basename);

    return Contentment::Generator::Plain->new({
        source     => scalar($file->content),
        properties => \%properties,
    });
}

=item Contentment::Generator::Plain::final_kind

Used to handle the "Contentment::Request::final_kind" hook.

=cut

sub final_kind {
	my $cgi = shift;
	my $kind = Contentment::MIMETypes->instance->mimeTypeOf($cgi->path_info);
	if ($kind) {
		Contentment->context->response->header->{-type} = $kind;
		return $kind;
	} else {
		return undef;
	}
}

=back

=head1 SEE ALSO

L<Contentment::MIMETypes>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
