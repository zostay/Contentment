# This build script takes *.in and replaces the @@VAR@@ variables
# with values from the build notes.

use Module::Build;
my $build = Module::Build->current;

while (@ARGV) {

	my $outfile = shift @ARGV;
	my $infile  = "$outfile.in";

	open IFH, "$infile" or die "Cannot open file $infile to generate $outfile.";
	open OFH, ">$outfile" or die "Cannot open file $outfile for generation.";

	my $first_line = <IFH>;
	while (my ($key, $value) = each %notes) {
		$first_line =~ s/\@\@$key\@\@/$value/ig;
	}
	
	if ($first_line =~ /^#!/) {
		print OFH $first_line;
		print OFH "\n# This file was automatically generated. DO NOT EDIT!!!\n";
		print OFH "# You should edit $infile, instead.\n\n";
	} else {
		print OFH "# This file was automatically generated. DO NOT EDIT!!!\n";
		print OFH "# You should edit $infile, instead.\n\n";
		print OFH $first_line;
	}

	my %notes = $build->notes;
	while (<IFH>) {
		while (my ($key, $value) = each %notes) {
			s/\@\@$key\@\@/$value/ig;
		}
		print OFH;
	}

	close IFH;
	close OFH;

	my $mode = (stat $infile)[2] & 0777;
	chmod $mode, $outfile;
}
