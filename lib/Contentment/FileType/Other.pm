package Contentment::FileType::Other;

use strict;
use warnings;

use Log::Log4perl;
use MIME::Types;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

our $VERSION = '0.01';

sub filetype_match { 1 }

sub kind { 
	my $class = shift;
	my $file  = shift;
	
	return MIME::Types->new->mimeTypeOf($file);
}

sub property { }

sub generate {
	my $class = shift;
	my $file  = shift;
	my $top   = shift;

	if ($top) {
		my $original_kind = $class->kind($file) || 'unknown';
		$log->debug("Regular file generates original kind of $original_kind");
		$Contentment::context->original_kind($original_kind);
	}

	my $fh = $file->open("r");
	binmode $fh;
	while (<$fh>) {
		print;
	}
	close $fh;

	return 1;
}

1
