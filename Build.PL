use strict;
use lib 'buildlib';

use Module::Build 0.20;
use Contentment::Build;

my $build = Contentment::Build->new(
	module_name        => 'Contentment',
	create_makefile_pl => 1,
	dist_version_from  => 'lib/Contentment.pm.in',
	license            => 'perl',
	requires           => {
		'HTML::Mason'		=> '1.20',
		'MIME::Types'       => '1.13',
		'perl'				=> '5.8.1',
		'SPOPS'				=> '0.87', 
		'SPOPSx::Ginsu'     => '0.58', 
		'SQL::Translator'   => '0.06', 
		'YAML'				=> '0.35', 
	},
	PL_files           => {
		'lib/Contentment.pm.PL' 	=> 'lib/Contentment.pm',
		'etc/Contentment.conf.PL'	=> 'etc/Contentment.conf',
	},
);

my $confdir   = $build->{args}{confdir}       || '/etc/Contentment';
my $basedir   = $build->{args}{basedir}       || '/usr/share/Contentment';
my $sampledir = $build->{args}{sampledir}     || '/usr/local/share/Contentment';
my $cgidir    = $build->{args}{cgidir}        || "/$basedir/cgi-bin";
my $tempdir   = $build->{args}{tempdir}       || '/tmp/mason/data';

$build->notes(confdir => $confdir);
$build->notes(basedir => $basedir);
$build->notes(sampledir => $sampledir);
$build->notes(cgidir => $cgidir);
$build->notes(tempdir => $tempdir);

print "Configuration installation directory: ",$build->notes('confdir'),"\n";
print "Mason base directory:                 ",$build->notes('basedir'),"\n";
print "Sample site installation directory:   ",$build->notes('sampledir'),"\n";
print "CGI directory:                        ",$build->notes('cgidir'),"\n";
print "Temporary Mason directory:            ",$build->notes('tempdir'),"\n";

$build->create_build_script;