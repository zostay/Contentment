package Contentment::FileType::POD;

use strict;
use warnings;

use base 'Contentment::FileType::Other';

use Log::Log4perl;
use MIME::Types;
use Text::Balanced qw/ extract_quotelike /;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

our $VERSION = '0.01';

sub filetype_match { 
	my $class = shift;
	my $file  = shift;

	return $file->path =~ /\.pod$|\.pm$/;
}

sub real_kind { 
	my $class = shift;
	my $file  = shift;

	if ($file->path =~ /\.pod$/) {	
		return 'text/x-pod';
	} else {
		return 'text/x-perl';
	}
}

sub decode_property {
	my $key   = shift;
	my $value = shift;

	my $quote = extract_quotelike $value;

	if ($quote) {
		return ($key => $quote);
	} elsif ($value =~ /^(\w+)$/) {
		return ($key => $1);
	} else {
		return ();
	}
}

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

sub property { 
	my $class = shift;
	my $file  = shift;
	my $prop  = shift;

	return $class->props($file)->{$prop};
}

1
