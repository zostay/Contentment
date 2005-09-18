use strict;

use lib 'buildlib';
use Module::Build 0.2610;
use Contentment::Build;

my $build = Contentment::Build->new(
	module_name        => 'Contentment',
	dist_version_from  => 'lib/Contentment.pm',
	license            => 'perl',
	create_makefile_pl => 'passthrough',
	requires           => {
	},
	recommends         => {
		'Apache::Test' => '1.25',
	},
);

$build->create_build_script;
