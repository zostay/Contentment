package Contentment::FileType::Other;

use strict;
use warnings;

use Log::Log4perl;
use MIME::Types;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

our $VERSION = '0.01';

my $mimetypes;
sub mimetypes {
	unless (defined $mimetypes) {
		$mimetypes = MIME::Types->new;
	}

	return $mimetypes;
}


sub filetype_match { 1 }

sub real_kind { 
	my $class = shift;
	my $file  = shift;
	
	return $class->mimetypes->mimeTypeOf($file);
}

sub generated_kind {
	my $class = shift;
	my $file  = shift;

	return $class->real_kind($file);
}

sub property { }

sub generate {
	my $class = shift;
	my $file  = shift;

	my $fh = $file->open("r");
	binmode $fh;
	while (<$fh>) {
		print;
	}
	close $fh;

	return 1;
}

1
