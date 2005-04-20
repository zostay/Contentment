use Module::Build;
my $build = Module::Build->current;

my $outfile = shift @ARGV;
open FH, ">$outfile" or die "Cannot open file $outfile for generation.";

my $confdir   = $build->notes('etc_dir');
my $basedir   = $build->notes('master_dir');
my $sampledir = $build->notes('sample_dir');
my $tempdir   = $build->notes('tmp_dir');

print FH <<EOF;
# This file was automatically generated during installation. You may want to
# see $confdir/Contentment.defaults.conf for default values
# and documentation. After customizing this file, it should be renamed to
# $confdir/Contentment.conf.
#
# You will probably want/need to edit this file to get everything working
# properly.

temp_dir: "$tempdir"
comp_dirs:
 - [ sample, "$sampledir" ]
 - [ master,  "$basedir" ]
log4perl_conf: "$confdir/log4perl.conf"
EOF

close FH;
