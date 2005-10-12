package Contentment::FileType::Template;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Contentment::FileType::Other';

use Contentment::Hooks;
use Contentment::Log;
use Contentment::Template::Provider;
use Template;

sub template_configuration {
	# Base the configuration on Contentment::Plugins::Template->configuration
	my $conf = Contentment::Setting->instance->{'Contentment::Plugin::Template'}{'configuration'};
	my %conf = %{ $conf || {} };
	my $iter;

	# Add Contentment::Template::Provider as one of the guys responsible for
	# fetch()-ing templates
	$conf{LOAD_TEMPLATES} = [
		Contentment::Template::Provider->new,
	];

	# Modify the PLUGINS field with the return values from the
	# Contentment::FileType::Template::plugins hook handlers.
	$iter = Contentment::Hooks->call_iterator('Contentment::FileType::Template::plugins');
	while ($iter->next) {
		$conf{PLUGINS} = { %{ $conf{PLUGINS} }, $iter->call };
	}

	# Allow handlers to modify any part of the configuration with the
	# Contentment::FileType::Template::configuration hook.
	Contentment::Hooks->call('Contentment::FileType::Template::configuration',
		\%conf,
	);

	# Output is ALWAYS to STDOUT. No meddling kids!
	$conf{OUTPUT} = \*STDOUT;

	return \%conf;
}

my $template;
sub template {
	return $template if $template;

	Contentment::Log->debug("Creating a new template singleton.");

	my $conf = Contentment::FileType::Template->template_configuration;
	return $template = Template->new($conf);
}

sub real_kind {
	return 'text/x-template-toolkit-2';
}

sub generated_kind {
	my $class = shift;
	my $file  = shift;

	# Strip off the .tt2 extension
	my $file_without_ext = $file->basename;
	$file_without_ext =~ s/\.tt2$//;

	# Return the MIME-Type of the nested extension or return the contents of the
	# "kind" metadata field.
	return eval { $class->mimetypes->mimeTypeOf($file->basename) 
		|| $class->template->context->template($file)->kind };
}

sub properties { ('for_template_toolkit') }

sub get_property {
	my $class = shift;
	my $file  = shift;
	my $key   = shift;

	die "Bad key '$key'." unless $key =~ /^\w+$/;

	return 1 if $key eq 'for_template_toolkit';

	return $class->template->context->template($file)->$key;
}

sub generate_headers { () }

sub generate {
	my $class = shift;
	my $file  = shift;
	my %args  = @_;

	$class->template->process($file, \%args)
		or die $class->template->error();

	return 1;
}

sub match {
	local $_ = ''.shift;
	/\.tt2/ && return 'Contentment::FileType::Template';
	return undef;
}

1
