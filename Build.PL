use strict;

use Module::Build 0.2610;

my $build = Module::Build->new(
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
