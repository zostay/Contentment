use strict;
use lib 'buildlib';

use File::Basename;
use Module::Build 0.2610;
use Contentment::Build;

# The --install_path argument is rather less useful than I'd hoped. Thus, I'll
# make it as useful as I need. So there.

my @args = @ARGV;
my @newargs;
my %relocs;

while (my $arg = shift @args) {
	if ($arg eq '--install_path') {
		my $path = shift @args;
	
		# Let Module::Build do the whining about errors.
		unless (defined $path && $path =~ /=/) {
			push @newargs, $arg;
			push @newargs, $path if defined $path;
			push @newargs, @args if @args;
			last;
		}

		my ($here, $there) = split /=/, $path;

		if ($here =~ /[\/-]/) {
			# Aha! Let's make sure this gets relocated properly.
			$relocs{$here} = $there;
		} else {
			# It's not one of mine. I'll just leave it alone.
			push @newargs, $arg, $path;
		}
	} else {
		# Again, not mine. Give it back.
		push @newargs, $arg;
	}
}
@ARGV = @newargs;

my $build = Contentment::Build->new(
	module_name        => 'Contentment',
	dist_version_from  => 'lib/Contentment.pm',
	license            => 'perl',
	create_makefile_pl => 'passthrough',
	requires           => {
		'Class::Accessor'         => '0.19',
		'Data::UUID'		      => '0.11',
		'DateTime::Format::DBI'   => '0.031',
		'File::System'            => '1.13',
		'HTML::Mason'		      => '1.20',
		'Log::Log4perl'		      => '0.47',
		'MIME::Types'             => '1.13',
		'perl'				      => '5.6.1',
		'SPOPS'				      => '0.87', 
		'SPOPSx::Tool::DateTime'  => '0.02',
		'SPOPSx::Tool::YAML'      => '0.03',
		'SQL::Translator'         => '0.06', 
		'YAML'				      => '0.35', 
	},
	recommends         => {
		'Apache::Test'            => '1.25',
		'DBD::mysql'              => '2.9008',
		'DateTime::Format::MySQL' => '0.0301',
		'FCGI'                    => '0.67',
		'Pod::Simple'             => '3.02',
		'Text::Balanced'	      => '1.95',
	},
	PL_files           => {
		'buildlib/expand-notes.PL' 	=> [
			'docroots/htdocs/cgi-bin/handler.cgi',
			'docroots/htdocs/cgi-bin/handler.fcgi',
			'etc/Contentment.conf.sample', 
			'etc/log4perl.conf.file',
			'lib/Contentment/Config.pm',
		],
		'buildlib/docindex.PL'		=> 'lib/Contentment/Manual.pod',
	},
);

# Locating the various directories of Contentment has been nasty-ugly. I've
# revamped this a bit. Hopefully, this is a little more sane. 
#
# Basically, what I really want is a central installation directory like this:
#
# - .../Contentment/
#   - bin/
#   - docroots/
#     - htdocs/
#       - cgi-bin/
#     - master/
#     - sample/
#     - site/
#   - etc/
#   - lib/
#     - Contentment.pm
#     - Contentment/
#     - ...
#   - logs/
#   - tmp -> /tmp/Contentment/
# - /tmp/Contentment/
#
# However, experience shows that frequently "docroots/master" and "cgi-bin" need
# to relocted within some predefined and immovable location. Other parts might
# need to be reloacted too, so we won't restrict relocs to these guys.
#
# A second factor is that we are moving the libraries into a specific location.
# This is because each Contentment installation needs it's own copy of the
# libraries since the installed libs have a hard coded location for the
# configuration files and such. I may be able to work around this eventually,
# but that's an optimization for later.

my $cms_root = $build->{args}{cms_root};

$build->{properties}{install_base} ||= "/usr/local/Contentment";

my $cms_root = $build->{properties}{install_base};

while (my ($here, $there) = each %relocs) {
	$build->{properties}{install_path}{$here} = $there;
}

$build->{properties}{install_path}{'bin'}      ||= "$cms_root/bin";
$build->{properties}{install_path}{'docroots'} ||= "$cms_root/docroots";
$build->{properties}{install_path}{'etc'}      ||= "$cms_root/etc";
$build->{properties}{install_path}{'logs'}     ||= "$cms_root/logs";
$build->{properties}{install_path}{'tmp'}      ||= '/tmp/'.basename($cms_root);

$build->notes('basename'   => basename($cms_root));
$build->notes('etc_dir'    => $build->{properties}{install_path}{'etc'});
$build->notes('htdocs_dir' =>
	$build->{properties}{install_path}{'docroots/htdocs'} ||
	"$build->{properties}{intall_path}{docroots}/htdocs");
$build->notes('master_dir' =>
	$build->{properties}{install_path}{'docroots/master'} ||
	"$build->{properties}{install_path}{docroots}/master");
$build->notes('site_dir'   =>
	$build->{properties}{install_path}{'docroots/site'} ||
	"$build->{properties}{install_path}{docroots}/site");
$build->notes('sample_dir' =>
	$build->{properties}{install_path}{'docroots/sample'} ||
	"$build->{properties}{install_path}{docroots}/sample");
$build->notes('tmp_dir'    => $build->{properties}{install_path}{'tmp'});
$build->notes('cgi_dir'    => 
	$build->{properties}{install_path}{'docroots/htdocs/cgi-bin'} ||
	$build->{properties}{install_path}{'docroots/htdocs'}."/cgi-bin" ||
	"$build->{properties}{install_path}{docroots}/htdocs/cgi-bin");
$build->notes('logs_dir'   => $build->{properties}{install_path}{'logs'});
$build->notes('lib_dir'    =>
	$build->{properties}{install_path}{'lib'} || "$cms_root/lib");

$build->add_build_element('mason');
$build->add_build_element('config');
$build->create_build_script;
