use Module::Build;
my $build = Module::Build->current;

my $outfile = shift @ARGV;
open FH, ">$outfile" or die "Cannot open file $outfile for generation.";

my $confdir   = $build->notes('confdir');
my $basedir   = $build->notes('basedir');
my $sampledir = $build->notes('sampledir');
my $tempdir   = $build->notes('tempdir');

print FH <<EOF;
# This file was automatically generated during installation. You may want to
# see $confdir/Contentment.defaults.conf for default values
# and documentation.
#
# You will probably want/need to edit this file to get everything working
# properly.

temp_dir: "$tempdir"
comp_dirs:
 - [ local, "$sampledir" ]
 - [ base,  "$basedir" ]
log4perl_conf: "$confdir/log4perl.conf"
EOF

close FH;
