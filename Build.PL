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
		'Cache::Cache'      => 0,
		'CGI'               => 0,
        'Class::Delegator'  => 0,
        'Cwd'               => 0,
		'Data::UUID'        => 0,
		'DateTime'          => 0,
        'Digest'            => 0,
        'Exception::Class'  => 1.22, # so Contentment::Exception->caught works
		'File::System'      => 1.16,
		'IO::NestedCapture' => 0,
		'List::MoreUtils'   => 0,
		'MIME::Types'       => 0,
		'Oryx'              => 0.16,
		'Pod::Simple'       => 0,
        'Readonly'          => 0,
		'Template'          => 2,
		'Text::Balanced'    => 0,
		'Test::Deep'        => 0,
		'YAML'              => 0,
	},
	recommends         => {
		'Apache::Test' => '1.25',
	},
);

$build->create_build_script;
