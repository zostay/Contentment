package Contentment::VFS;

use strict;
use warnings;

use Contentment;
use File::Spec;
use Log::Log4perl;

our $VERSION = '0.01';

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::VFS - Provides a virtual file system for Contentment

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

=head1 STATUS

As of this writing, this really isn't much of a "VFS" at all. It is merely a wrapper for the regular file system. This should change in the future.

=head1 VFS API

The main class of the VFS is C<Contentment::VFS>. This is a singleton object that can be referenced by doing:

  $vfs = Contentment::VFS->new;

Once you have a C<$vfs> object, you can use it to lookup files and directories. See the documentation on C<Contentment::VFS::Thing>, C<Contentment::VFS::File>, and C<Contentment::VFS::Directory> below.

=head2 Contentment::VFS

=over

=item $vfs = Contentment::VFS-E<gt>new

Returns a reference to the VFS singleton object.

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

=item $thing = $vfs-E<gt>lookup($path)

Given a path relative to the VFS root, this returns a reference to the matching C<Contentment::VFS::Thing> or returns C<undef>

=cut

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

=item $thing = $vfs-E<gt>lookup_source($path)

This is like C<lookup>, except that instead of looking for an exact filename match, this will attempt to find the first file that could be used as a source to generate output for the given path.

If the C<$path> matches a file (not a directory) exactly, then the C<Contentment::VFS::Thing> representing that file is returned.

If the C<$path> matches a directory exactly, then this method checks to see if that directory contains an index. The index is any file starting with F<index> with any file extension. If the directory doesn't contain an index file, then C<undef> is returned.

Finally, this method searches for a file matching C<$path> without regard to file extensions. If a match is found, it is returned.

In the case of multiple matches at any point, the choice of match is undefined.

=cut

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

=item @files = $vfs-E<gt>glob(@globs)

Each glob in C<@globs> should be a Unix-style file glob pattern relative to the VFS root. Each of these patterns is applied to the VFS to return any matching filename. The C<@files> returned are merely full paths (within the VFS root) and I<not> C<Contentment::VFS::Thing> objects. The C<@files> are returned in sorted order.

=cut

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

=item @files = $vfs-E<gt>find($want, @dirs)

This method searches for all files within the given directories C<@dirs> that match the criteria given by the subroutine reference C<$want>. For each file found in each of the directories given, the C<Contentment::VFS::Thing> object for that file is passwd to the C<$want> subroutine. If the subroutine returns true, then the file is included in the resultant list of files C<@files>.

In addition, the C<$want> method can determine whether or not a subdirectory is descended. By default, all subdirectories are searched. However, this can be turned off directory-by-directory by setting the value of C<prune> to true on that directory.

=cut

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

=back

=head2 Contentment::VFS::Thing

This is the base class for all "things" stored in the VFS. Generally, all VFS plugins will provide at least a file thing. If a VFS may contain subdirectories, it should also provide a directory thing. Depending on the needs and capabilities, a VFS may also provide other kinds of things.

=over

=cut

sub new {
	my $class = shift;
	my $root  = shift;
	my $path  = shift;

	my $canonpath = File::Spec->catfile($root, $path);
	-e $canonpath
		or die "VFS Things only wrap real files: $canonpath";

	return bless { 
		root      => File::Spec->canonpath($root), 
		path      => File::Spec->canonpath($path), 
		canonpath => File::Spec->canonpath($canonpath),
	}, $class;
}

=item $path = $thing-E<gt>root

I'm not sure of the value of this method generally, but it is very useful for the general file system plugin. It lets us know which Mason root contains this file.

=cut

sub root      { return shift->{root} }

=item $path = $thing-E<gt>path

This names the VFS path to the thing.

=cut

sub path      { return shift->{path} }

=item $path = $thing-E<gt>canonpath

I'm not sure of the value of this method generally, but it is very useful for the general file sysetm plugin. It gives us the full "real" path to the file in the file system.

=cut

sub canonpath { return shift->{canonpath} }

=item $parent_thing = $thing-E<gt>parent

Tries to find the thing that is the parent of this C<$thing>. Either returns the C<Contentment::VFS::Thing> found or C<undef>.

=cut

sub parent {
	my $self = shift;

	my @path = File::Spec->splitpath($self->{path});
	pop @path;
	return Contentment::VFS->new->lookup(File::Spec->catdir(@path));
}

=item $stat = $thing-E<gt>stat

This performs a filesystem C<stat> on the thing. This is only useful for the file system plugin.

=cut

sub stat {
	my $self = shift;

	return $self->{stat} if $self->{stat};

	my @stat = stat $self->canonpath;
	return $self->{stat} = \@stat;
}

=item $test = $thing-E<gt>is_file

Returns true if this thing is a plain file.

=cut

sub is_file { 0 }

=item $test = $thing-E<gt>is_directory

Returns true if this thing is a directory.

=cut

sub is_directory { 0 }

=item $value = $thing-E<gt>property($key)

Checks the thing to see if it has the named property. It either returns that property's value or C<undef>.

=cut

sub property {
	my $self = shift;
	local $_ = shift;

	defined $_ or
		die "Missing required 'key' argument.";
	
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
		/^depth$/   && do { 
			my $path = $self->path;
			$path =~ s/\/+$//;
			$path =~ s/\/\/+/\//g;
			return scalar(@d = ($path =~ m#/#g)) ;
		};
	}

	if (my $filetype = $self->lookup_source->filetype) {
		my $property = $filetype->property($self->lookup_source, $_);
		if (defined $property) {
			$log->debug("Found $self property value '$_' : '$property'");
		} else {
			$log->debug("Not found $self property value '$_'");
		}		
		return $property;
	} else {
		return;
	}
}

=item $result = $thing-E<gt>generate

This causes the output of the thing to be generated and printed to the currently selected file handle. The result of this generation is also returned.

=cut

sub generate {
	my $self = shift;

	if (my $filetype = $self->filetype) {
		return $filetype->generate($self, @_);
	} else {
		return;
	}
}

package Contentment::VFS::File;

use FileHandle;

our @ISA = qw/ Contentment::VFS::Thing /;

=back

=head2 Contentment::VFS::File

This class will most certainly be moved when the VFS implementation is completed. This code is specific to real file system access only.

=over

=item $fh = $file_thing-E<gt>open($access)

Opens the file associated with the C<$file_thing> and returns a reference to the opened file handle or C<undef> on failure. The C<$access> value determines what access to the file is requested as per L<FileHandle>.

=cut

sub open {
	my $self = shift;
	return FileHandle->new($self->canonpath, @_);
}

=item @lines = $file_thing-E<gt>lines

Returns all of the lines (newline terminated) of the file in a list.

=cut

sub lines {
	my $self = shift;

	my $fh = $self->open("r") or die "Cannot open ",$self->canonpath,": $!";
	my @lines = <$fh>;
	close $fh;

	return @lines;
}

=item $test = $file_thing-E<gt>is_file

Always returns true.

=cut

sub is_file { 1 }

=item $kind = $file_thing-E<gt>real_kind

Determines the filetype of the file represented and returns the real kind of the file.

=cut

sub real_kind {
	my $self = shift;

	if (my $filetype = $self->filetype) {
		return $filetype->real_kind($self);
	} else {
		return 'unknown';
	}
}

=item $kind = $file_thing-E<gt>generated_kind

Determines the filetype of the file represented and returns the generated kind of the file.

=cut

sub generated_kind {
	my $self = shift;

	if (my $filetype = $self->filetype) {
		return $filetype->generated_kind($self);
	} else {
		return 'unknown';
	}
}

=item $filetype = $file_thing-E<gt>filetype

Returns the filetype plugin which matches the file thing.

=cut

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

=item $thing = $file_thing-E<gt>lookup_source

Always returns C<$thing = $filething>.

=cut

sub lookup_source { shift }

package Contentment::VFS::Directory;

our @ISA = qw/ Contentment::VFS::Thing /;

=back

=head2 Contentment::VFS::Directory

This is specific to the filesystem plugin which will really be made it's own plugin rather than a built-in of the VFS at some future point.

=over

=item $test = $dir_thing-E<gt>is_directory

Alwayrs returns true.

=cut

sub is_directory { 1 }

=item $test = $dir_thing-E<gt>prune($set_prune)

Used during C<find> operations of C<Contentment::VFS> to determine whether to descend into child directories. Setting it to true will result in files under this directory being skipped. Setting it to false will result in files under this directory to be scanned.

=cut

sub prune {
	my $self = shift;
	my $prune = shift;

	$self->{prune} = 0 unless defined $self->{prune};
	$self->{prune} = $prune if defined $prune;
	return $self->{prune};
}

=item $thing = $dir_thing-E<gt>lookup_source

This uses L<Contentment::VFS> to attempt to find an index in the directory using C<lookup_source>.

=cut

sub lookup_source { 
	my $self = shift;

	return $self->{source} if $self->{source};

	$self->{source} = Contentment::VFS->new->lookup_source($self->path);

	warn "Could not find a source for directory $self" unless $self->{source};

	return $self->{source};
}

=item $filetype = $dir_thing-E<gt>filetype

Always returns C<undef>. Directories do not contain any content.

=cut

sub filetype { }

sub lines {
	my $self = shift;

	die "Cannot grab the lines of the directory ",$self->path;
}

package Contentment::VFS::FakeFile;

sub new {
	my $class = shift;
	return bless {}, $class;
}

=back

=head1 SEE ALSO

L<Contentment::FileType::Other>, L<Contentment::FileType::Mason>, L<Contentment::FileType::POD>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
