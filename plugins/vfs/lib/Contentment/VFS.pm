package Contentment::VFS;

use strict;
use warnings;

use Carp;
use Contentment;
use Contentment::Hooks;
use Contentment::Log;
use Contentment::Request;
use File::Spec;
use File::System;

our $VERSION = '0.12';

use base 'File::System::Passthrough';

=head1 NAME

Contentment::VFS - Provides a virtual file system for Contentment

=head1 DESCRIPTION

The purpose of a content management system is to provide a store for content.  Unfortunately, it is difficult to determine how such content should be represented and stored. As such, this class provides a "virtual file system" that allows the user to store components in a customized manner.

This class is used to wrap L<File::System::Object>s and provides additional functionality. 

=head1 VFS API

The VFS class is a singleton object that can be referenced by doing:

  $vfs = Contentment::VFS->new;

Once you have a C<$vfs> object, you can use it to lookup files and directories. Whenever possible, the VFS delegates work directly to L<File::System::Object>, so see that documentation for the basic details. Any additional functionality is described in this document.

=head2 Contentment::VFS

=over

=item $vfs = Contentment::VFS-E<gt>instance

Returns a reference to the VFS singleton object.

=cut

my $vfs;
sub instance {
	return $vfs if defined $vfs;

	my $class = shift;

	my $conf = Contentment->global_configuration;

	return $vfs = $class->SUPER::new($conf->{vfs});
}

=item $vfs = Contentment::VFS-E<gt>new

I<Deprecated.> Use C<instance> instead.

=cut

sub new {
	carp "The Contentment::VFS::new method is deprecated. Use Contentment::VFS::instance instead.";
	return shift->instance;
}

=item $source_obj = $obj-E<gt>lookup_source($path)

This is like C<lookup>, except that instead of looking for an exact filename match, this will attempt to find the first file that could be used as a source to generate output for the given path.

If no path is given and C<$obj-E<gt>has_content> returns true, then C<$source_obj = $obj>. If no path is given and C<$obj-E<gt>has_content> returns false, but C<$obj-E<gt>is_container> returns true, then a check is performed to see if a file named C<index.*> can be found inside of the container. If so, that object is returned.

If the C<$path> matches a file (not a directory) exactly, then the object representing that file is returned.

If the C<$path> matches a directory exactly, then this method checks to see if that directory contains an index. The index is any file starting with F<index> with any file extension. If the directory doesn't contain an index file, then C<undef> is returned.

Finally, this method searches for a file matching C<$path> without regard to file extensions. If a match is found, it is returned.

In the case of multiple matches at any point, the choice is arbitrary.

=cut

sub lookup_source {
	my $self = shift;
	my $path = shift;

	unless (defined $path) {
		if ($self->has_content) {
			return $self;
		} elsif ($self->is_container) {
			$path = '.';
			# and continue...
		} else {
			# what the crap?
			return undef;
		}
	}

	my $result;

	Contentment::Log->debug("searching for a source for %s", [$path]);
	my $file = $self->lookup($path);
	if (defined $file && $file->has_content) {
		$result = $file;
	} elsif (defined $file && $file->is_container) {
		Contentment::Log->debug("searching for directory index %s", ["$path/index.*"]);
		my @files = $self->glob("$path/index.*");
		for my $index_file (@files) {
			if ($file = $self->lookup($index_file) and $file->has_content) {
				$result = $file;
				last;
			}
		}
	} else {
		my $copy = $path;
		$copy =~ s/\.[\w\.]+$//;

		Contentment::Log->debug("searching for alternate file %s", ["$copy.*"]);

		my @files = $self->glob("$copy.*");
		for my $source_file (@files) {
			if ($file = $self->lookup($source_file) and $file->has_content) {
				$result = $file;
				last;
			}
		}
	}

	return $result;
}

=item @properties = $obj-E<gt>properties

When C<$obj-E<gt>has_content> returns true, this method will attempt to lookup the filetype and return the list of additional properties reported by the filetype in addition to those native to the filesystem.

=cut

sub properties {
	my $self = shift;

	my %properties = map { ($_ => 1) } $self->SUPER::properties;

	if ($self->has_content && $self->filetype) {
		$properties{$_}++ foreach ($self->filetype->properties($self));
	}

	return keys %properties;
}

=item $value = $obj-E<gt>get_property($key)

When C<$obj-E<gt>has_content> returns true, this method will lookup both properties native to the file system and those for the file type plugin.

=cut

sub get_property {
	my $self = shift;
	my $key  = shift;

	my $value = $self->SUPER::get_property($key);
	if (defined $value) {
		return $value;
	} elsif ($self->has_content and $self->filetype and
			$value = $self->filetype->get_property($self, $key)) {
		return $value;
	} else {
		return undef;
	}
}

=item $headers = $obj-E<gt>generate_headers(@_)

This method is only valid when C<has_content> returns true. This calls the C<generate_headers> method of the file type returned by the C<filetype> method or returns an empty hash reference.

=cut

sub generate_headers {
	my $self = shift;

	$self->has_content
		or croak "Cannot call 'generate_headers' on a file with no content.";

	if (my $filetype = $self->filetype) {
		return $filetype->generate_headers($self, @_);
	} else {
		return {};
	}
}

=item $result = $obj-E<gt>generate(@_)

This causes the output of the object to be generated and printed to the currently selected file handle. The result of this generation is also returned.

This method is only valid when C<has_content> returns true. Generation differs from just calling the C<content> method in that this uses the C<filetype> to interpret and write the file. Generate may take arguments, which are passed directly on to the C<generate> method of the associated file type plugin.

=cut

sub generate {
	my $self = shift;

	$self->has_content
		or croak "Cannot call 'generate' on file with no content.";

	if (my $filetype = $self->filetype) {
		return $filetype->generate($self, @_);
	} else {
		return;
	}
}

=item $kind = $file_thing-E<gt>real_kind

Determines the filetype of the file represented and returns the real kind of the file.

This method is only valid when C<has_content> is true.

=cut

sub real_kind {
	my $self = shift;

	$self->has_content
		or croak "Cannot call 'real_kind' on file with no content.";

	if (my $filetype = $self->filetype) {
		return $filetype->real_kind($self);
	} else {
		return 'unknown';
	}
}

=item $kind = $file_thing-E<gt>generated_kind(@_)

Determines the filetype of the file represented and returns the generated kind of the file. Note that it is important to pass the same set of arguments to this method as to the C<generate> method, as a file type plugin may generate different types based upon the arguments given.

This is only valid when C<has_content> is true.

=cut

sub generated_kind {
	my $self = shift;

	$self->has_content
		or croak "Cannot call 'generated_kind' on file with no content.";

	if (my $filetype = $self->filetype) {
		return $filetype->generated_kind($self, @_);
	} else {
		return 'unknown';
	}
}

=item $filetype = $file_thing-E<gt>filetype

Returns the filetype plugin which matches the file thing.

This is only valid when C<has_content> is true.

=cut

sub filetype {
	my $self = shift;

	$self->has_content
		or croak "Cannot call 'filetype' on non-content file $self.";

	defined $self->{filetype} and
		return $self->{filetype};

	my $iter = Contentment::Hooks->call_iterator('Contentment::FileType::match');
	while ($iter->next) {
		my $plugin = $iter->call($self);
		if ($plugin) {
			Contentment::Log->debug("Matched file %s with filetype %s", [$self,$plugin]);
			return $self->{filetype} = $plugin;
		}
	}

	Contentment::Log->warning("Couldn't match %s with any filetype", [$self]);

	return;
}

=item @files = $obj-E<gt>ancestors

This is a handy method that returns the parent, grandparent, and so forth for the current object C<$obj>. The files are returned in order such that the ultimate parent is first and the nearest parent is last. (Handy for crumbtrail generation, etc.)

Returns an empty list if the current object is the root.

=cut

sub ancestors {
	my $self = shift;

	return () if $self->is_root;
	
	my $file_path;
	my $root = $self->root;
	my @ancestors = $root;

	croak "Root failure." unless $self->root;

	my $orig_path = $self->path;
	$orig_path =~ s/^\///;

	for my $path (split /\//, $orig_path) {
		$file_path .= "/$path";
		my $file = $self->lookup($file_path)
			or croak "Error looking up file '$file_path'";
		push @ancestors, $file;
	}

	return @ancestors;
}

=item $vfs-E<gt>add_layer($index, $filesystem)

Layers another file system object over the current file system. If you want to make the new layer top priority set C<$index> to 0. If you want it the lowest priority, set C<$index> to -1.

If the file system wrapped is not a L<File::System::Layered> object, it is made such an object with the current file system object made the only internal layer.

=cut

sub add_layer {
	my $self       = shift;
	my $index      = shift;
	my $filesystem = shift;

	unless ($self->{fs}->isa('File::System::Layered')) {
		Contentment::Log->debug("Switching VFS to a layered file system.");
		$self->{fs} = File::System->new('Layered',
			$self->{fs},
		);
	} 

	my $fsname;
	if (ref $filesystem eq 'ARRAY') {
		$fsname = "$filesystem->[0](".join(', ', @{$filesystem}[1 .. $#$filesystem]).")";
	} else {
		$fsname = ref $filesystem;
	}

	my @layers = $self->{fs}->get_layers;
	
	if ($index < 0) {
		$index = @layers + $index + 1;
	}

	Contentment::Log->debug("Adding new file system %s to index %d", [$fsname,$index]);

	splice @layers, $index, 0, $filesystem;
	$self->{fs}->set_layers(@layers);
}

=item $vfs-E<gt>get_layers

Lists the layers in the file system.

=cut

sub get_layers {
	my $self = shift;
	if ($self->{fs}->isa('File::System::Layered')) {
		$self->{fs}->get_layers;
	} else {
		($self->{fs});
	}
}

=item $vfs-E<gt>remove_layer($index)

Removes the layer found at the given C<$index>. Throws an exception if the file system isn't layered or there is only one layer left.

=cut

sub remove_layer {
	my $self = shift;
	my $index = shift;

	if ($self->{fs}->isa('File::System::Layered')) {
		my @layers = $self->{fs}->get_layers;
		croak "Cannot remove the last layer of the file system." if @layers == 1;

		splice @layers, $index, 1;

		$self->{fs}->set_layers(@layers);
	} else {
		croak "Cannot remove layers from an unlayered file system.";
	}
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::VFS::resolve

Handles the "Contentment::Response::resolve" handler. Looks for a file in the VFS to return as a component for rendering.

=cut

sub resolve {
	my $path = shift;
	my $vfs = Contentment::VFS->instance;

	unless ($path) {
		my $q = Contentment::Request->cgi;
		$path = $q->path_info;
	}

	my $file = $vfs->lookup($path);
	if ($file && $path !~ /\/$/ && $file->is_container) {
		my $generator = Contentment::Generator->new;
		$generator->set_generator(sub {
			Contentment::Log->debug("Redirecting directory %s -> %s/", [$path,$path]);
			Contentment::Response->redirect("$path/", %{ Contentment::Request->cgi->Vars });
		});
		return $generator;
	} else {
		return $file || $vfs->lookup_source($path);
	}
}

=head1 SEE ALSO

L<File::System>, L<File::System::Other>, L<File::System::Passthrough>, L<Contentment::FileType::Other>, L<Contentment::FileType::Mason>, L<Contentment::FileType::POD>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
