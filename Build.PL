use strict;
use lib 'buildlib';

use Module::Build 0.21;
use Contentment::Build;

my $build = Contentment::Build->new(
	module_name        => 'Contentment',
	create_makefile_pl => 1,
	dist_version_from  => 'lib/Contentment.pm.in',
	license            => 'perl',
	requires           => {
		'Class::Accessor'   => '0.19',
		'HTML::Mason'		=> '1.20',
		'Log::Log4perl'		=> '0.47',
		'MIME::Types'       => '1.13',
		'perl'				=> '5.6.1',
		'SPOPS'				=> '0.87', 
		'SQL::Translator'   => '0.06', 
		'YAML'				=> '0.35', 
	},
	recommends         => {
		'Pod::Simple'       => '3.02',
		'Text::Balanced'	=> '1.95',
	},
	PL_files           => {
		'lib/Contentment.pm.PL' 			=> 'lib/Contentment.pm',
		'etc/Contentment.conf.PL'			=> 'etc/Contentment.conf',
		'docs/Contentment/Manual.pod.PL'	=> 'docs/Contentment/Manual.pod',
	},
);

my $confdir   = $build->{args}{confdir}       || '/etc/Contentment';
my $basedir   = $build->{args}{basedir}       || '/var/www/localhost/htdocs';
my $sampledir = $build->{args}{sampledir}     || '/var/www/localhost/content';
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
