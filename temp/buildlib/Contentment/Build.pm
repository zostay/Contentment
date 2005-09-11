package Contentment::Build;

use strict;

our $VERSION = '0.03';

BEGIN {
	use Module::Build;
	my $build_pkg = 
		eval { require Apache::TestMB } ? 'Apache::TestMB' : 'Module::Build';
	our @ISA = ($build_pkg);
}

use ExtUtils::Install;
use File::Path;
use File::Spec;

sub ACTION_release {
	my $self = shift;

	require Module::Release;

	# Let's <> work the way Module::Release expects	
	@ARGV = ();

	my $r = Module::Release->new;
	$r->clean;
	$r->build_makefile;
	$r->test;
	$r->dist;
	$r->dist_test;
	$r->check_cvs;
	exit if $self->args('t');

	$r->check_for_passwords;
	$r->cvs_tag;
	$r->ftp_upload;
	$r->pause_claim;
	$r->sf_login;
	$r->sf_qrs;
	$r->sf_release;

	print "Done.\n";
}

sub ACTION_install {
	my $self = shift;

	$self->SUPER::ACTION_install;

	my $logs = $self->notes('logs_dir');
	chmod 0600, File::Spec->catfile($logs, "contentment.log");
}

sub ACTION_distdir {
	my $self = shift;

	$self->SUPER::ACTION_distdir;

	$self->do_system('svn log svn+ssh://sterling@contentment.org/home/sterling/svn/trunk/Contentment > '.File::Spec->catfile($self->dist_dir, 'Changelog'));
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

sub ACTION_test {
	my $self = shift;

	$self->ACTION_build;

	mkpath('t/htdocs/cgi-bin', 1);
	mkpath('t/tmp', 1);

	open IN, 'blib/docroots/htdocs/cgi-bin/handler.cgi'
		or die "Cannot open blib/docroots/htdocs/cgi-bin/handler.cgi: $!";
	open OUT, '>t/htdocs/cgi-bin/handler.cgi',
		or die "Cannot open t/htdocs/cgi-bin/handler.cgi: $!";

	while (<IN>) {
		print OUT $_ unless /^use lib/;

		if (/^use lib/) {
			print OUT "BEGIN { chdir '../../..' }\n\n";
			print OUT "use blib;\n";
			print OUT "use lib 'buildlib';\n";
		} elsif (/^use Contentment;/) {
			print OUT "use Contentment::Test;\n";
		}
	}

	close IN;
	close OUT;

	$self->make_executable('t/htdocs/cgi-bin/handler.cgi');

	$self->add_to_cleanup('t/htdocs/cgi-bin/handler.cgi');
	$self->add_to_cleanup('t/tmp');

	$self->SUPER::ACTION_test;
}

sub ACTION_dbclean {
	my $self = shift;

	require blib;
	require Contentment;
	require Contentment::Test;
	require Contentment::SPOPS;

	my $dbh = Contentment::SPOPS->global_datasource_handle;
	for my $table ($dbh->tables(undef, undef, undef, undef)) {
		print STDERR "Droping table $table\n";
		$dbh->do("drop table $table");
	}
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
