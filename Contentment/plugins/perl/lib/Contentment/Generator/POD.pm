package Contentment::Generator::POD;

use strict;
use warnings;

use base 'Contentment::Generator::Plain';

use Params::Validate qw( validate_with :types );
use Text::Balanced qw( extract_quotelike );

our $VERSION = '0.13';

=head1 NAME

Contentment::Generator::POD - A generator for Plain Old Documentation

=head1 SYNOPSIS

  $source = <<'END_OF_POD';
  =head1 NAME

  Test - This is a test.

  =head1 DESCRIPTION

  This is a little test of L<Contentment::Gneerator::POD>.

  =cut
  END_OF_POD

  my $generator = Contentment::Generator::POD->new({
      properties => {
          foo => 1,
          bar => 2,
      },
      source => $source,
  });

  my $title       = $generator->get_property('title');
  my $description = $generator->get_property('description');

  $generator->generate();

=head1 DESCRIPTION

This is a generated specifically geared for use with Perl's POD, or Plain Old Documentation, format. This class inherits from L<Contentment::Generator::Plain>.

=over

=item $generator = Contentment::Generator::POD-E<gt>new(\%args)

This constructs a POD generator. It takes the following arguments.

=over

=item source (required)

This option specifies the source to use for the documentation. It may be specified in any of the forms that L<Contentment::Generator::Plain> supports.

=item properties (optional, defaults to {})

This specifies any properties you want to give generator. This properties will be overridden by any properties specified within the file itself. Properties may be specified in the file itself in four different ways.

=over

=item 1.

You may specify the property with a C<=begin meta> section:

  =begin meta
      foo => 1
      bar => 'A string.'
  =end meta
  =cut

The properties are specified using a hash-like syntax where the keys may be placed within quotes or not and the values may be placed in quotes or not. The parser for this is pretty simple, so try to stick to the simple stuff as the above.

=item 2.

You may specify the property with a C<=for meta> section:

  =for meta
    foo => 1
    bar => 'A string.'

  new_paragraph => 'NOT A PROPERTY!'
  =cut

This is exactly the same as the C<=begin meta> section, but a C<=for meta> section lasts until a new paragraph is started.

=item 3.

You may specify a heading named "NAME" followed by a title and description:

  =head1 NAME

  Title - This is the description

  =cut

This will create a property named "title" with the value "Title" and a property named "description" with the value "This is the description".

This is in following with the standard man-page convention that most POD files follow.

=item 4.

If the first heading encountered is not named "NAME", then it will be used to set a property named "title" with the given heading. For example,

  =head1 This is the Title

  =cut

Would result in a property named "title" with the value "This is the Title" being stored.

=back

If two or more methods are used to define the same property, the way the values clobber each other isn't well-defined.

=back

=cut

sub new {
    my $self = shift;

    my %p = validate_with(
        params => \@_,
        spec => {
            source => {
                type    => GLOBREF | CODEREF | SCALAR,
            },
            properties => {
                type    => HASHREF,
                default => {},
            },
        },
        allow_extra => 1,
    );

    $p{properties}{kind} ||= 'text/x-pod';

    return $self->SUPER::new(\%p);
}

# ($key, $value) = decode_properties($key, $value)
#
# This is used internally and should not be messed with. It's used to decode the
# properties stored in the "meta" sections.
#
# =cut

sub decode_property {
	my $key   = shift;
	my $value = shift;

	my $quote = (extract_quotelike $value)[5];

	if ($quote) {
		return ($key => $quote);
	} elsif ($value =~ /^(\w+)$/) {
		return ($key => $1);
	} else {
		return ();
	}
}

=item $source = $self->source

This overrides the method provided by L<Contentment::Generator::PLain>. In addition to reading the source, this method also parses properties out of the source.

=cut

sub source {
	my $self = shift;

    # Skip it if the source has been parsed already.
    return $self->SUPER::source if $self->is_sourced;

    # Split the file into lines like <>
    my $source = $self->SUPER::source;
    my @lines  = split /^/m, $source;

	my %props = %{ $self->properties };
	my $meta;
	my $title;
    for (@lines) {
		if ($meta && /^\s*(\w+)\s*=>\s*(.*)$/) {
			my ($key, $value) = decode_property($1, $2);
			if (defined $key) {
				$props{$key} = $value;
			} 
            
            else {
				warn "Invalid property value for $key in =begin meta ",
                     "on line $.";
			}
		} 
        
        elsif ($meta && /^=end\s+meta\s*$/) {
			$meta = 0;
		} 
        
        elsif ($meta && !/^\s*$/) {
			warn "Invalid line in the middle of metadata section on line $.";
		} 
        
        elsif (!$meta && /^=begin\s+meta\s*$/) {
			$meta = 1;
		} 
        
        elsif (!$meta && /^=for\s+meta\s+(\w+)\s*=>\s*(.*)$/) {
			my ($key, $value) = decode_property($1, $2);
			if (defined $key) {
				$props{$key} = $value;
			} 
            
            else {
				warn "Invalid property value for $key in =for meta on line $.";
			}
		} 
        
        elsif (!$props{title} && !$meta && !$title && /^=head1\s+NAME\s*$/) {
			$title = 1;
		} 
        
        elsif (!$meta && $title && /^\s*(\S*)\s*-\s*(.*)$/) {
			$title = 0;
			$props{title} = $1;
			$props{abstract} = $2;
		} 
        
        elsif (!$props{title} && !$meta && !$title && /^=head1\s+(.*)$/) {
			$props{title} = $1;
		}
	}

    $self->properties(\%props);

    return $source;
}

=item $properties = $generator-E<gt>properties

Returns the hash of properties for the generator. This will include any properties found in the source.

=cut

sub properties {
    my $self = shift;

    # Check the source
    $self->source;

    return $self->SUPER::properties(@_);
}

=back

=head1 SEE ALSO

L<Contentment::Generator::Plain>, L<Contentment::Generator::PerlScript>, L<perlpod>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforege.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
