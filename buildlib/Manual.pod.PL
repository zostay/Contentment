use strict;
use warnings;

use File::Find;
use Pod::Find qw/ contains_pod /;

sub pod_wanted {
	my $array = shift;

	if (/^\.svn$|^CVS$|\.in$/) {
		$File::Find::prune++;
		return;
	}

	push @$array, $File::Find::name if contains_pod($_);
}

sub perl_api_index {
	my @files;
	find(sub { pod_wanted(\@files) }, 'lib');
	return sort @files;
}

sub mason_api_index {
	my @files;
	find(sub { pod_wanted(\@files) }, 'docroots/master');
	return sort @files;
}

sub title_and_abstract {
	my $file = shift;

	open FH, $file or die "Failed to open $file: $!\n";

	my $in_pod = 0;
	while (<FH>) {
		if ($in_pod) {
			if (/^\s*([^-]*?)\s*-\s*(.*)$/) {
				close FH;
				return [ $1, $2 ];
			} elsif (/^=cut/) {
				$in_pod = 0;
			}
		} elsif (/^=\w+/) {
			$in_pod = 1;
		}
	}
	close FH;

	die "Failed to find a title/abstract in $file.";
}

sub print_index {
	my $output;
	for (@_) {
		$output .= "L<$_->[0]> - $_->[1]\n\n";
	}
	return $output;
}

my $perl_api  = print_index(map { title_and_abstract($_) } perl_api_index);
my $mason_api = print_index(map { title_and_abstract($_) } mason_api_index);

my $out = shift @ARGV;
my $in  = "$out.in";

open IN, $in or die "Cannot read $in: $!\n";
open OUT, ">$out" or die "Cannot write $out: $!\n";

print OUT "=for comment AUTOMATICALLY GENERATED! DO NOT MODIFY!!! MODIFY Manual.pod.in INSTEAD!!!\n\n";

while (<IN>) {
	s/@\@PERL_API_INDEX@@/$perl_api/g;
	s/@\@MASON_API_INDEX@@/$mason_api/g;

	print OUT $_;
}
close OUT;
close IN;
