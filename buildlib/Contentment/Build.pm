package Contentment::Build;

use strict;

use base 'Module::Build';

use ExtUtils::Install;
use File::Path;
use File::Spec;

sub ACTION_install {
	my $self = shift;

	$self->SUPER::ACTION_install;
	
	$self->ACTION_install_conf;
	$self->ACTION_install_sample;
	$self->ACTION_install_base;
	$self->ACTION_install_cgi;
}

sub my_destdir { my $self = shift; $$self{properties}{destdir} || '/' }

sub safe_install {
	my $self     = shift;
	my $from_dir = shift;
	my $to_dir   = shift;

	my $safe_dir = File::Spec->catfile('blib', 'safe', $from_dir);
	mkpath($safe_dir);
	mkpath($to_dir);

	my @install;
	while (my $file = shift) {
		my $safe      = $file =~ s/^!//;
		my $from_file = File::Spec->catfile($from_dir, $file);
		my $to_file   = File::Spec->catfile($self->my_destdir, $to_dir, $file);

		unless ($safe && -e $to_file) {
			File::Copy::copy($from_file, $to_file);
		} else {
			warn "Preserving $to_file, installing to $to_file.new instead\n";
			File::Copy::copy($from_file, "$to_file.new");
		}
	}

	install({ 'read' => '', $safe_dir => $to_dir });
}

sub ACTION_install_conf {
	my $self = shift;

	$self->safe_install('etc', $self->notes('confdir'), qw/
		!Contentment.conf
		Contentment.defaults.conf
		!log4perl.conf
	/);
}

sub ACTION_install_sample {
	my $self = shift;

	my $sampledir = $self->my_destdir.$self->notes('sampledir');
	install({ 'read' => '', 'sample' => $sampledir });
}

sub ACTION_install_base {
	my $self = shift;

	my $basedir = $self->my_destdir.$self->notes('basedir');
	install({ 'read' => '', 'html' => $basedir });
}

sub ACTION_install_cgi {
	my $self = shift;

	my $cgidir = $self->my_destdir.$self->notes('cgidir');
	install({ 'read' => '', 'cgi-bin' => $cgidir });
}

1
