package Contentment::FileType::POD;

use strict;
use warnings;

use base 'Contentment::FileType::Other';

use Log::Log4perl;
use MIME::Types;
use Text::Balanced qw/ extract_quotelike /;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

our $VERSION = '0.02';

=head1 NAME

Contentment::FileType::POD - A file type plugin for handling Plain Old Documentation

=head1 DESCRIPTION

This is a generated specifically geared for use with Perl's POD, or Plain Old Documentation, format. This class inherits from L<Contentment::FileType::Other>.

=over

=item $test = Contentment::FileType::POD-E<gt>filetype_match($file)

Returns true if the file name ends with "C<.pod>" or "C<.pm>". Returns false otherwise.

=cut

sub filetype_match { 
	my $class = shift;
	my $file  = shift;

	return $file->path =~ /\.pod$|\.pm$/;
}

=item $kind = Contentment::FileType::POD-E<gt>real_kind($file)

Returns "C<text/x-pod>" if the file name ends with "C<.pod>" or "C<text/x-perl>" otherwise.

=cut

sub real_kind { 
	my $class = shift;
	my $file  = shift;

	if ($file->path =~ /\.pod$/) {	
		return 'text/x-pod';
	} else {
		return 'text/x-perl';
	}
}

# =item ($key, $value) = Contentment::FileType::POD-E<gt>decode_properties($key, $value)
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

# =item $properties = Contentment::FileType::POD-E<gt>props($file)
#
# Decodes the properties found in the file, caches them in the C<$file>, and
# returns the hash reference containing them.
#
# =cut

sub props {
	my $class = shift;
	my $file  = shift;

	if ($file->{ft_props}) {
		return $file->{ft_props};
	}

	my $fh = $file->open("r");
	my %props;
	my $meta;
	my $title;
	while (<$fh>) {
		if ($meta && /^\s*(\w+)\s*=>\s*(.*)$/) {
			my ($key, $value) = decode_property($1, $2);
			if (defined $key) {
				$props{$key} = $value;
			} else {
				warn "Invalid property value for $key in =begin meta of ",$file->path," line $.";
			}
		} elsif ($meta && /^=end\s+meta\s*$/) {
			$meta = 0;
		} elsif ($meta && !/^\s*$/) {
			warn "Invalid line in the middle of metadata section.";
		} elsif (!$meta && /^=begin\s+meta\s*$/) {
			$meta = 1;
		} elsif (!$meta && /^=for\s+meta\s+(\w+)\s*=>\s*(.*)$/) {
			my ($key, $value) = decode_property($1, $2);
			if (defined $key) {
				$props{$key} = $value;
			} else {
				warn "Invalid property value for $key in =for meta of ",$file->path," line $.";
			}
		} elsif (!$props{title} && !$meta && !$title && /^=head1\s+NAME\s*$/) {
			$title = 1;
		} elsif (!$meta && $title && /^\s*(\S*)\s*-\s*(.*)$/) {
			$title = 0;
			$props{title} = $1;
			$props{abstract} = $2;
		} elsif (!$props{title} && !$meta && !$title && /^=head1\s+(.*)$/) {
			$props{title} = $1;
		}
	}
	close $fh;

	return $file->{ft_props} = \%props;
}

=item @properties = Contentment::FileType::POD-E<gt>properties($file)

Returns the list of properties for the file.

=cut

sub properties {
	my $class = shift;
	my $file  = shift;

	return keys %{ $class->props($file) };
}

=item $value = Contentment::FileType::POD-E<gt>property($file, $value)

This method returns properties detected in one of two ways. First, the "title" and "abstract" properties are detected by searching for a heading named "NAME". The next non-blank line formated like "title - abstract" is then used to file those fields. For example,

  =head1 NAME

  Contentment::FileType::POD - A file type plugin for handling Plain Old Documentation

This fragment would give us a property named "title" of "Contentment::FileType::POD" and a property named "abstract" of "A file type plugin for handling Plain Old Documentation".

The second way is to searches the file for "meta" sections. This uses the "=begin"/"=end" and "=for" sections. Each property is a Perl word followed by a "=>" and then a Perl string. For example,

  =begin meta
  date           => "2005-3-17 7:23"
  author         => q(Andrew Sterling Hanenkamp)
  favorite_movie => 'Napoleon Dynamite'
  =end meta

  =for meta foo => 'Quick property.'

Here we would have a property named "date" of "2005-3-17 7:23", "author" of "Andrew Sterling Hanenkamp", "favorite_movie" of "Napoleon Dynamite", and "foo" of "Quick property."

=cut

sub property { 
	my $class = shift;
	my $file  = shift;
	my $prop  = shift;

	return $class->props($file)->{$prop};
}

=back

=head1 SEE ALSO

L<Contentment::FileType::Other>, L<perlpod>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforege.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
