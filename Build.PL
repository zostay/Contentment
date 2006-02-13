use strict;

use lib 'inc';
use Module::Build 0.2610;
use Contentment::Build;

my $build = Contentment::Build->new(
	module_name        => 'Contentment',
	dist_version_from  => 'lib/Contentment.pm',
	license            => 'perl',
	create_makefile_pl => 'passthrough',
	requires           => {
		'Cache::Cache'          => 0,
        'Carp'                  => 0,
		'CGI'                   => 0,
        'Class::Accessor'       => 0,
        'Class::Date'           => 0,
        'Class::Delegator'      => 0,
        'Class::Singleton'      => 0,
        'Class::WhiteHole'      => 0,
        'Cwd'                   => 0,
		'Data::UUID'            => 0,
		'DateTime'              => 0,
        'Digest'                => 0,
        'Exception::Class'      => 1.22, # Contentment::Exception->caught
        'File::Copy'            => 0,
        'File::Path'            => 0,
        'File::Spec'            => 0,
		'File::System'          => 1.16,
        'HTML::TokeParser'      => 0,
        'HTTP::Request::Common' => 0,
        'IO::Handle'            => 0,
		'IO::NestedCapture'     => 0,
		'List::MoreUtils'       => 0,
        'List::Util'            => 0,
        'LWP::UserAgent'        => 0,
		'MIME::Types'           => 0,
		'Oryx'                  => 0.16,
        'Params::Validate'      => 0,
		'Pod::Simple'           => 0,
        'Readonly'              => 0,
        'Scalar::Util'          => 0,
		'Template'              => 2,
		'Text::Balanced'        => 0,
		'Test::Deep'            => 0,
        'URI'                   => 0,
		'YAML'                  => 0,
	},
	recommends         => {
		'Apache::Test' => '1.25',
        'CGI::Fast'    => 0,
        'FCGI'         => 0,
	},
);

$build->create_build_script;
