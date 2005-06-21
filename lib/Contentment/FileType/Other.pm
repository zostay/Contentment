package Contentment::FileType::Other;

use strict;
use warnings;

use Cache::FileCache;
use DateTime;
use Log::Log4perl;
use MIME::Types;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

our $VERSION = '0.04';

=head1 NAME

Contentment::FileType::Other - Generic file type plugin

=head1 DESCRIPTION

This is a generic file type plugin, which is useful for inheriting from or to use as a catch-all for general files.

=over

=item $mimetypes = Contentment::FileType::Other-E<gt>mimetypes

Returns a L<MIME::Types> object. Eventually, this object will allow custom MIME types to be specified for the object, but for now it merely provides access to a global singleton.

=cut

my $mimetypes;
sub mimetypes {
	unless (defined $mimetypes) {
		$mimetypes = MIME::Types->new;
	}

	return $mimetypes;
}

=item $test = Contentment::FileType::Other-E<gt>filetype_match($file)

Always returns true.

=cut

sub filetype_match { 1 }

=item $kind = Contentment::FileType::Other-E<gt>real_kind($file)

Returns the MIME type of the file based upon the result of passing the file name to L<MIME::Types>.

=cut

sub real_kind { 
	my $class = shift;
	my $file  = shift;
	
	return $class->mimetypes->mimeTypeOf($file);
}

=item $kind = Contentment::FileType::Other-E<gt>generated_kind($file)

In this case, this method is a synonym for C<real_kind>.

=cut

sub generated_kind {
	my $class = shift;
	my $file  = shift;

	return $class->real_kind($file);
}

=item @properties = Contentment::FileType::Other-E<gt>properties($file)

Always returns an empty list.

=cut

sub properties { () }

=item $value = Contentment::FileType::Other-E<gt>get_property($file, $key)

Always returns C<undef>.

=cut

sub get_property { }

=item $headers = Contentment::FileType::Other-E<gt>generate_headers($file, @args)

Uses the file's C<mtime> property (if set) to set the C<Last-Modified> header.

=cut

sub generate_headers {
	my $class = shift;
	my $file  = shift;

	my %headers;

	my $mtime = $file->get_property('mtime');
	if ($mtime) {
		$mtime = DateTime->from_epoch( epoch => $mtime );
		$headers{'Last-Modified'} = sprintf("%s, %02d %s %d %s GMT",
				$mtime->day_abbr, $mtime->day, $mtime->month_abbr,
				$mtime->year, $mtime->hms);
	}

	return \%headers;
}

=item $result = Contentment::FileType::Other-E<gt>generate($file, @args)

Always returns true. Writes the contents of the file to the currently selected file handle.

=cut

sub generate {
	my $class = shift;
	my $file  = shift;

	my $fh = $file->open("r");
	binmode $fh;

	my $buf;
	while (read $fh, $buf, 8192) {
		print $buf;
	}
	close $fh;

	return 1;
}

=back

=head1 SEE ALSO

L<MIME::Types>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
