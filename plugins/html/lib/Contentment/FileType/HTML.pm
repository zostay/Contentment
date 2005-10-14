package Contentment::FileType::HTML;

use strict;
use warnings;

use base 'Contentment::FileType::Other';

our $VERSION = '0.05';

=head1 NAME

Contentment::FileType::HTML - File type plugin for HTML files

=head1 DESCRIPTION

This is a file type plugin for HTML files. It basically understands the C<title> and C<meta> tags. It strips the body out of the HTML and passes it on. This way, each HTML file is a complete file in and of itself, but we can wrap it in nice themes without too much effort.

=over

=item $test = Contentment::FileType::HTML-E<gt>filetype_match($file)

Returns true when the file name matches /\.m?html?/i.

=cut

sub filetype_match {
	my $class = shift;
	my $file  = shift;

	"$file" =~ /\.m?html?/i;
}

=item $kind = Contentment::FileType::HTML-E<gt>real_kind($file)

Returns 'text/html'.

=cut

sub real_kind { 'text/html' }

=item $kind = Contentment::FileType::HTML-E<gt>generated_kind($file)

Returns 'text/html'.

=cut

sub generated_kind { 'text/html' }

# =item $properties = Contentment::FileType::HTML-E<gt>props($file)
#
# Decodes the properties found in the file, caches them in the file, and returns
# the hash reference containing them.
#
# =cut

sub props {
	my $class = shift;
	my $file  = shift;

	return $file->{ft_props} if defined $file->{ft_props};

	my %props;

	local $_ = $file->content;

	($props{title}) = m[<title>(.*?)</title>]si;

	while (m[<\s*meta[^>]+?name=(?:"[^"]+"|\S+\s)[^>]*?>]sig) {
		my $meta = $&;

		$meta =~ m{name=(?:"([^"]+)"|([^\\>\s]+))}si;
		my $key = $1 || $2;

		$meta =~ m{content=(?:"([^"]*)"|([^\\>\s]*))}si;
		my $value = $1 || $2;

		$props{$key} = $value;
	}
		
	return $file->{ft_props} = \%props;
}

=item @properties = Contentment::FileType::HTML-E<gt>properties($file)

Returns list of properties available in the file.

=cut

sub properties {
	my $class = shift;
	my $file  = shift;

	return keys %{ $class->props($file) };
}

=item $result = Contentment::FileType::HTML-E<gt>get_property($file, $key)

Returns the contents of the C<title> tag when C<$key> is "title".

Returns the contents of the C<content> attribute of any C<meta> tag where the key matches the given C<$key>.

=cut

sub get_property {
	my $class = shift;
	my $file  = shift;
	my $key   = shift;

	return $class->props($file)->{$key};
}

=item $result = Contentment::FileType::HTML-E<gt>generate($file)

Returns the body of the HTML file.

=cut

sub generate {
	my $class = shift;
	my $file  = shift;

	my $fh = $file->open("r");
	my $state = 'head';
	my $other_text;
	my $printed = 0;
	while (<$fh>) {
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
	close $fh;

	unless ($printed) {
		print $other_text;
	}

	return 1;
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::FileType::HTML::match

Handles the "Contentment::FileType::match" hook.

=cut

sub match {
	local $_ = shift;
	/\.html?$/ && return 'Contentment::FileType::HTML';
}

=back

=head1 SEE ALSO

L<Contentment::FileType::Other>

=head1 AUTHOR

Andrew Sterling Hanenkamp E<lt>hanenkamp@cis.ksu.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1