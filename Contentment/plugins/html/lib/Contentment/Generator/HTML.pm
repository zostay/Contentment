package Contentment::Generator::HTML;

use strict;
use warnings;

our $VERSION = '0.07';

use base 'Contentment::Generator::Plain';

use Params::Validate qw( validate_with :types );

=head1 NAME

Contentment::Generator::HTML - Generator for HTML text

=head1 SYNOPSIS

  my $generator = Contentment::Generator::HTML->new({
      source => <<'END_OF_HTML',
  <html>
  <head>
  <title>This is an example.</title>
  <meta name="foo" content="1"/>
  <meta name="bar" content="2"/>
  </head>
  <body>
  <h1>This is an example.</h1>

  <p>Exampling we will go! Exampling we will go!<br/>
  Hi-Ho-A-Merry-Oh! Exampling we will go!</p>
  </body>
  </html>
  END_OF_HTML

=head1 DESCRIPTION

This is a generator for HTML files. It basically understands the C<title> and C<meta> tags. It strips the body out of the HTML and passes it on. This way, each HTML file is a complete file in and of itself, but we can wrap it in nice themes without too much effort.

=over

=item $generator = Contentment::Generator::HTML-E<gt>new(\%args)

Constructs an HTML generator. It accepts the following arguments:

=over

=item source (required)

This is the HTML text to generate. It takes the same forms as L<Contentment::Generator::Plain>'s constructor.

=item properties (optional, defaults to {})

The C<get_property()> method searches for meta-tags in the HTML source and uses those as properties. If you wish to have additional properties that aren't defined in the meta tags, you may add them with this option. These options create additional properties, they do not override the meta tags in the file.

=cut

sub new {
    my $class = shift;
    my %p = validate_with(
        params => \@_,
        spec => {
            source => 1,
            properties => {
                type    => HASHREF,
                default => {},
            },
        },
    );

    $p{properties}{kind} ||= 'text/html';

    return $class->SUPER::new(\%p);
}

=item $properties = $generator-E<gt>properties

This decodes the properties found defined by meta-tags in the source as well as returning any properties set in the constructor. The meta-tags in the file will override any properties given to the constructor.

=cut

sub properties {
	my $self = shift;

    # Perform source processing of properties
    $self->source;

    return $self->SUPER::properties(@_);
}

=item $source = $generator-E<gt>source

Parses the HTML and it's properties in addition to reading the source.

=cut

sub source {
    my $self = shift;

    # Skip it if we've done it already
	return $self->SUPER::source if $self->is_sourced;

    # Otherwise we read the source and add any metadata found in it. This will
    # overwrite any properties set in the constructor that are also set as meta
    # tags in the HTML.
	my %properties = %{ $self->SUPER::properties };

    # Get the source
    my $source = $self->SUPER::source;

    # Is there a title? We assume sane HTML.
	($properties{title}) = $source =~ m[<title>(.*?)</title>]si;

    # Find all the meta tags and process each of them
    my @metas = ($source =~ m[<\s*meta[^>]+?name=(?:"[^"]+"|\S+\s)[^>]*?>]sig); 
    for my $meta (@metas) {

        # Find the meta name
		$meta =~ m{name=(?:"([^"]+)"|([^\\>\s]+))}si;
		my $key = $1 || $2;

        # Find the meta content
		$meta =~ m{content=(?:"([^"]*)"|([^\\>\s]*))}si;
		my $value = $1 || $2;

        # Set the property
		$properties{$key} = $value;
	}
		
    # Save the metadata
    $self->SUPER::properties(\%properties);

    # Return the source
    return $source;
}

=item $result = $generator-E<gt>get_property($key)

Returns the contents of the C<title> tag when C<$key> is "title".

Returns the contents of the C<content> attribute of any C<meta> tag where the key matches the given C<$key>.

=item $result = $generator-E<gt>generate

Prints the body of the HTML file.

=cut

sub generate {
	my $self = shift;

    # Fetch the source and split after newline each time just like <>
    my @source_line = split /^/m, $self->source;

    # Loop through the input and only print out the body
	my $state = 'head';
	my $other_text;
	my $printed = 0;
    foreach (@source_line) {
		if ($state eq 'head') {
			$other_text .= $_;
			if (m[<body]i) {
				if (m{<body.*?>(.*)$}si) {
					print $1;
					$state = 'body';
					$printed++;
				} else {
					$state = 'limbo';
				}
			}
		} elsif ($state eq 'limbo') {
			if (m{>(.*)$}si) {
				print $1;
				$state = 'body';
				$printed++;
			}
		} else {
			if (m[^(.*?)</body>]) {
				print $1;
				$printed++;
				last;
			} else {
				print;
				$printed++;
			}
		}
	}

    # In case we encounter an HTML file without a body tag, we just give up and
    # print the whole thing.
	unless ($printed) {
		print $other_text;
	}

	return 1;
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::Generator::HTML::match

Handles the "Contentment::FileType::match" hook.

=cut

sub match {
	my $file = shift;

	if ($file =~ /\.html?$/) { 
        my %properties      = %{ $file->properties_hash };
        $properties{kind} ||= 'text/html';

        return Contentment::Generator->generator('HTML', {
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

L<Contentment::FileType::Other>

=head1 AUTHOR

Andrew Sterling Hanenkamp E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
