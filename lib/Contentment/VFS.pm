package Contentment::VFS;

use strict;
use warnings;

use Contentment;
use File::Spec;
use Log::Log4perl;

our $VERSION = '0.01';

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::VFS - Provides a customized virtual file system

=head1 DESCRIPTION

The purpose of a content management system is to provide a store for content.
Unfortunately, it is difficult to determine how such content should be
represented and stored. As such, this class provides (or will provide when I
work on it some more) a "virtual file system" that allows the user to store
components in a customized manner.

This class will provide the logic for determining which file system plugin to
activate for a given path or set of paths. It will provide a system of virtual
"moun points" on which different "file systems" can be nested. It will provide
a way of natively accessing multiple versions of documents for file systems that
provide such access. However, as of this writing, it does none of these things.

This class merely provides a direct window into the real file system.

=cut

my $vfs;
sub new {
	return $vfs if defined $vfs;

	my $class = shift;

	my $conf = Contentment::configuration;

	return bless {
		bases => [ map $_->[1], @{ $conf->{comp_dirs} } ]
	}, $class;
}

sub lookup {
	my $self = shift;
	my $path = shift;

	if (UNIVERSAL::isa($path, 'Contentment::VFS::Thing')) {
		return $path;
	}

	$path = "/$path" unless $path =~ m#^/#;

	$log->debug("VFS Lookup: $path");

	for my $base (@{ $self->{bases} }) {
		my $full_path = File::Spec->catfile($base, $path);

		$log->debug("VFS Lookup checking full: $full_path");
		if (-e $full_path) {
			$log->debug("VFS Lookup exists: $full_path");

			if (-d $full_path) {
				$log->debug("VFS Lookup directory: $full_path");
				return Contentment::VFS::Directory->new($base, $path);
			} else {
				$log->debug("VFS Lookup file: $full_path");
				return Contentment::VFS::File->new($base, $path);
			}
		}
	}

	$log->debug("VFS Lookup failed: $path");
	return;
}

sub lookup_source {
	my $self    = shift;
	my $relname = shift;

	my $result;

	$log->debug("searching for a source for $relname");
	my $file = $self->lookup($relname);
	if (defined $file && $file->is_file) {
		$result = $file;
	} elsif (defined $file && $file->is_directory) {
		$log->debug("searching for directory index $relname/index.*");
		my @files = $self->glob("$relname/index.*");
		for my $index_file (@files) {
			if ($file = $self->lookup($index_file) and $file->is_file) {
				$result = $file;
				last;
			}
		}
	} else {
		my $copy = $relname;
		$copy =~ s/\.[\w\.]+$//;

		$log->debug("searching for alternate file $copy.*");

		my @files = $self->glob("$copy.*");
		for my $source_file (@files) {
			if ($file = $self->lookup($source_file) and $file->is_file) {
				$result = $file;
				last;
			}
		}
	}

	return $result;
}

sub glob {
	my $self = shift;

	$log->debug("VFS Glob files: ", join(' ', @_));

	my %files;
	for my $base (@{ $self->{bases} }) {
		for my $glob (@_) {
			my $full_glob = File::Spec->catfile($base, $glob);

			$log->debug("VFS Globbing base: $full_glob");

			for my $file (map { s#^$base/##; $_ } glob $full_glob) {
				$files{$file}++;
			}
		}
	}

	my @files = sort keys %files;
	$log->debug("VFS Globbing found: ", join(' ', @files));

	return @files;
}

sub find {
	my $self = shift;
	my $want = shift;

	my @all_files = $self->glob(map { "$_/*" } @_);
	my @wanted_files;
	while (@all_files) {
		my $file = $self->lookup(shift @all_files);

		my $keep = $want->($file);
		push @wanted_files, $file if $keep;

		if ($file->is_directory && !$file->prune) {
			push @all_files, $self->glob("$file/*");
		}
	}

	return @wanted_files;
}

package Contentment::VFS::Thing;

use File::Basename ();

use overload 
	'""' => sub { shift->path };

sub new {
	my $class = shift;
	my $root  = shift;
	my $path  = shift;

	my $canonpath = File::Spec->catfile($root, $path);
	-e $canonpath
		or die "VFS Things only wrap real files: $canonpath";

	return bless { 
		root      => $root, 
		path      => $path, 
		canonpath => $canonpath,
	}, $class;
}

sub root      { return shift->{root} }
sub path      { return shift->{path} }
sub canonpath { return shift->{canonpath} }

sub stat {
	my $self = shift;

	return $self->{stat} if $self->{stat};

	my @stat = stat $self->canonpath;
	return $self->{stat} = \@stat;
}

sub is_file { 0 }
sub is_directory { 0 }

sub property {
	my $self = shift;
	local $_ = shift;

	my @d;
	SWITCH: {
		/^path$/    && do { return $self->path };
		/^name$/    && do { return File::Basename::basename($self->path) };
		/^dev$/     && do { return $self->stat->[0] };
		/^ino$/     && do { return $self->stat->[1] };
		/^mode$/    && do { return $self->stat->[2] };
		/^nlink$/   && do { return $self->stat->[3] };
		/^uid$/     && do { return $self->stat->[4] };
		/^gid$/     && do { return $self->stat->[5] };
		/^rdev$/    && do { return $self->stat->[6] };
		/^size$/    && do { return $self->stat->[7] };
		/^atime$/   && do { return $self->stat->[8] };
		/^mtime$/   && do { return $self->stat->[9] };
		/^ctime$/   && do { return $self->stat->[10] };
		/^blksize$/ && do { return $self->stat->[11] };
		/^blocks$/  && do { return $self->stat->[12] };
		/^depth$/   && do { return scalar(@d = ($self->path =~ m#/#g)) };
	}

	if (my $filetype = $self->filetype) {
		my $property = $filetype->property($self, $_);
		if (defined $property) {
			$log->debug("Found $self property value $_ : $property");
		} else {
			$log->debug("Not found $self property value $_");
		}		
		return $property;
	} else {
		return;
	}
}

sub generate {
	my $self = shift;
	my $top  = shift;

	if (my $filetype = $self->filetype) {
		if ($top) {
			my $original_kind = $self->generated_kind;
			$Contentment::context->original_kind($original_kind);
			$log->debug("File type $filetype says $self->{path} generates original kind of $original_kind");
		}

		return $filetype->generate($self);
	} else {
		return;
	}
}

package Contentment::VFS::File;

use FileHandle;

our @ISA = qw/ Contentment::VFS::Thing /;

sub open {
	my $self = shift;
	return FileHandle->new($self->canonpath, @_);
}

sub lines {
	my $self = shift;

	my $fh = $self->open("r") or die "Cannot open ",$self->canonpath,": $!";
	my @lines = <$fh>;
	close $fh;

	return @lines;
}

sub is_file { 1 }

sub real_kind {
	my $self = shift;

	if (my $filetype = $self->filetype) {
		return $filetype->real_kind($self);
	} else {
		return 'unknown';
	}
}

sub generated_kind {
	my $self = shift;

	if (my $filetype = $self->filetype) {
		return $filetype->generated_kind($self);
	} else {
		return 'unknown';
	}
}

sub filetype {
	my $self = shift;
	defined $self->{filetype} and
		return $self->{filetype};

	my $conf = Contentment::configuration;

	for my $plugin (@{ $conf->{filetype_plugins} }) {
		eval "require $plugin";
		warn "Failed to load $plugin: $@" if $@;

		if ($plugin->can('filetype_match') && $plugin->filetype_match($self)) {
			$log->debug("Matched file $self with filetype $plugin");
			return $self->{filetype} = $plugin;
		}
	}

	warn("Couldn't match $self with any filetype");

	return;
}

sub lookup_source { shift }

package Contentment::VFS::Directory;

our @ISA = qw/ Contentment::VFS::Thing /;

sub is_directory { 1 }

sub prune {
	my $self = shift;
	my $prune = shift;

	$self->{prune} = 0 unless defined $self->{prune};
	$self->{prune} = $prune if defined $prune;
	return $self->{prune};
}

sub lookup_source { 
	my $self = shift;

	return $self->{source} if $self->{source};

	$self->{source} = Contentment::VFS->new->lookup_source($self->path);

	warn "Could not find a source for directory $self" unless $self->{source};

	return $self->{source};
}

sub filetype { }

package Contentment::VFS::FakeFile;

sub new {
	my $class = shift;
	return bless {}, $class;
}

sub property { }

1
