# This build script takes Contentment.pm.in and replaces the @@VAR@@ variables
# with proper values.

use Module::Build;
my $build = Module::Build->current;

my $outfile = shift @ARGV;
my $infile  = "$outfile.in";

open IFH, "$infile" or die "Cannot open file $infile to generate $outfile.";
open OFH, ">$outfile" or die "Cannot open file $outfile for generation.";

print OFH "# This file was automatically generated. DO NOT EDIT!!!\n\n";

my %notes = $build->notes;
while (<IFH>) {
	while (my ($key, $value) = each %notes) {
		s/\@\@$key\@\@/$value/ig;
	}
	print OFH;
}

close IFH;
close OFH;
