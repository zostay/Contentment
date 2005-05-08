package Contentment::Build;

use strict;

use base 'Module::Build';

use ExtUtils::Install;
use File::Path;
use File::Spec;

sub ACTION_install {
	my $self = shift;

	$self->SUPER::ACTION_install;

	my $logs = $self->notes('logs_dir');
	chmod 0600, File::Spec->catfile($logs, "contentment.log");
}

sub ACTION_distdir {
	my $self = shift;

	$self->SUPER::ACTION_distdir;

	$self->do_system('svn log svn+ssh://sterling@contentment.org/home/sterling/svn/Contentment/trunk > '.File::Spec->catfile($self->dist_dir, 'Changelog'));
}

sub ACTION_build {
	my $self = shift;

	$self->SUPER::ACTION_build;

	$self->ACTION_empty_logs;
}

sub ACTION_empty_logs {
	my $self = shift;

	my $logs = File::Spec->catfile($self->blib, 'logs');
	mkpath($logs);

	my $log = File::Spec->catfile($logs, 'contentment.log');
	open FH, ">$log" or die "Failed to create $log";
	close FH;
}

sub process_mason_files {
	my $self = shift;

	my $files = $self->find_all_files('mason', 'docroots');

	while (my ($file, $dest) = each %$files) {
		my $result = $self->copy_if_modified(from => $file, to => File::Spec->catfile($self->blib, $dest) ) or next;
		$self->make_executable($result) if $result =~ /\.cgi$/;
	}
}

sub process_config_files {
	my $self = shift;

	my $files = $self->find_all_files('config', 'etc');

	while (my ($file, $dest) = each %$files) {
		$self->copy_if_modified(from => $file, to => File::Spec->catfile($self->blib, $dest) );
	}
}

sub skip_files {
	return 0 if -d $File::Find::name;
	!m/\bRCS\b|\bCVS\b|,v$|\B\.svn\b|~$|\.tmp$|\.old$|\.bak$|\#$|\b\.#|\.in$/;
}

sub find_all_files {
	my $self = shift;
	my $type = shift;
	my $dir  = shift;

	if (my $files = $self->{properties}{"${type}_files"}) {
		return { map $self->localize_file_path($_), %$files };
	}

	return {} unless -d $dir;
	return { map {$_, $_}
		map $self->localize_file_path($_),
		grep !/\.#/,
		@{ $self->rscan_dir($dir, \&skip_files) } };
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

1
