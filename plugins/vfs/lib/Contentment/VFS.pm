package Contentment::VFS;

use strict;
use warnings;

use Contentment;
use Contentment::Exception;
use Contentment::Hooks;
use Contentment::Log;
use Contentment::Request;
use File::Spec;
use File::System;

our $VERSION = '0.19';

use base 'File::System::Passthrough';

=head1 NAME

Contentment::VFS - Provides a virtual file system for Contentment

=head1 DESCRIPTION

The purpose of a content management system is to provide a store for content.  Unfortunately, it is difficult to determine how such content should be represented and stored. As such, this class provides a "virtual file system" that allows the user to store components in a customized manner.

=head2 VFS FEATURES

The basic functionality required is identical to that of L<File::System::Object>. The L<Contentment::VFS> class is actually a subclass of L<File::System::Passthrough>, which wraps the file system defined by the "vfs" key of the global configuration. It will employ the use of an internal L<File::System::Layered> object and L<File::System::Table> object to perform file system layering and mounting.

By using the C<add_layer()> and C<mount()> methods, you can use existing L<File::System::Object> implementations or custom implementations to add additional files and directories to the VFS.

In addition to the functionality provided by each of these file system implementations, the VFS adds the ability to provide files through a simple set of hooks. This doesn't provide as much power as defining a full blown file system object implementation, but is far simpler.

Another change from the L<File::System> implementation is that the use of the C<content()> method is discouraged. Instead, use the C<generator()> method to return an object capable of generating the file's content. If the VFS hook functionality is used, it's probable that C<content()> will return an empty string for a file while the C<generator()> returned will output text.

=head2 VFS HOOKS

If you want to extend the VFS without a full-blown mount, register a named hook handler for the "Contentment::VFS::simple" hook. The name registered is the base path your hook will provide files under. The name must include a starting slash, but do not include the traling slash.

  # Be sure to NOT include a trailing "/"
  Contentment::Hooks->register(
      hook => 'Contentment::VFS::simple',
      name => '/node',
      code => \&Contentment::Node::simple,
  );

When someone looks up a path starting with the name you register, the handler will be called. 

The handler will be passed a single argument, the relative path under the named path that was requested. (A lone slash ("/") will be passed if the user asks for the name you registered).

  my $vfs = $context->vfs;

  # The /node handler will be passed "/"
  my $obj = $vfs->lookup('/node');

  # The /node handler will be passed "/"
  my $obj = $vfs->lookup('/node');

  # The /node handler will be passed "/id/42/rev/142"
  my $obj = $vfs->lookup('/node/id/42/rev/142');

Based upon the path given, your handler should return a reference to a hash describing the file/directory that exists at that path. Return C<undef> if no such file exists.

The returned hash may contain the following keys:

=over

=item type (required)

This describes the file type. This is a string containing at least a "d" or an "f" or a combination of them. If "d" is given, then the file is a directory and contains other files. If "f" is given, then the file is contains file data.

=item children (required if type contains "d")

This should be a reference to an array of strings. Each string is the name of a valid path immediately within the directory.

=item generator (required if type contains "f")

This should be a reference to a generator object.

=item properties (optional, defaults to {})

This is a hash of the properties to set on the file system object (in addition to basename, dirname, path, and object_type which are handled by the VFS for you).

=back

=head2 VFS API

The VFS class is a singleton object that can be referenced by doing:

  $vfs = $context->vfs;

Once you have a C<$vfs> object, you can use it to lookup files and directories. Whenever possible, the VFS delegates work directly to L<File::System::Object>, so see that documentation for the basic details. Any additional functionality is described in this document.

=head2 METHODS

=over

=item $vfs = $context-E<gt>vfs

Returns a reference to the VFS singleton object.

=cut

my $vfs;
sub instance {
	return $vfs if defined $vfs;

	my $class = shift;

	my $conf = Contentment->global_configuration;

    $vfs = $class->SUPER::new(
        File::System->new('Layered', [ 'Table', '/' => $conf->{vfs} ])
    );

    $vfs->{table_layer} = 0;

	return $vfs;
}

# The following have been defined to implement the Contentment::VFS::simple hook.
sub _simple_lookup {
    my $self = shift;
    my $path = $self->normalize_path(shift);

    my @children;

    my $iter = Contentment::Hooks->call_iterator('Contentment::VFS::simple');
    while ($iter->next) {
        my $name = $iter->name;

        my $short_path = $path;
        if ($short_path =~ s/^$name//) {
            $short_path = "/$short_path" unless $short_path =~ m{^/};
        
#            Contentment::Log->debug(
#                'Asking simple VFS handler named %s for %s',
#                [$name,$short_path]);

            my $file_args = $iter->call($short_path);

            if ($file_args) {
#                Contentment::Log->debug('Found a simple VFS file for %s',
#                    [$path]);

                $file_args->{path} = $path;
                return bless {
                    fs      => $self->{fs}, 
                    special => $file_args,
                }, ref $self;
            } else {
                return undef;
            }
        }

        elsif ($name =~ s/^$path//) {
            
            Contentment::Log->debug(
                'Creating simple parent directory named %s for simple mount %s',
                [$path,$name]
            );

            my ($next_child) = split m{/}, $name;
            push @children, $next_child;
        }

        # else { no match, skip it }
    }

    if (@children) {
        return bless {
            fs      => $self->{fs},
            special => {
                type     => 'd',
                children => \@children,
                path     => $path,
            },
        };
    }

    Contentment::Log->debug('Did not find a simple VFS file for %s',[$path]);
    return undef;
}

sub exists {
    my $self = shift;
    return $self->File::System::Object::exists(@_);
}

sub is_root {
    my $self = shift;
    return '' if defined $self->{special};
    return $self->SUPER::is_root(@_);
}

sub parent {
    my $self = shift;
    
    if (defined $self->{special}) {
        return $self->lookup($self->dirname_of_path($self->path));
    }

    else {
        return $self->SUPER::parent(@_);
    }
}

sub is_creatable {
    my $self = shift;
    return '' if defined $self->{special};
    return $self->SUPER::is_creatable(@_);
}

sub create {
    my $self = shift;
    if (defined $self->{special}) {
        Contentment::Exception->throw(
            message => 'Cannot create files here.',
        );
    }
    else {
        return $self->SUPER::create(@_);
    }
}

sub is_valid {
    my $self = shift;
    if (defined $self->{special}) {
        return 1;
    }
    else {
        return $self->SUPER::is_valid(@_);
    }
}

sub has_content {
    my $self = shift;
    if (defined $self->{special}) {
        return scalar $self->{special}{type} =~ /f/;
    }

    else {
        return $self->SUPER::has_content;
    }
}

sub is_container {
    my $self = shift;
    if (defined $self->{special}) {
        return scalar $self->{special}{type} =~ /d/;
    }

    else {
        return $self->SUPER::is_container;
    }
}

sub properties {
    my $self = shift;

    if (defined $self->{special}) {
        return (
            qw( object_type basename dirname path ),
            keys %{ $self->{special}{properties} },
        );
    }

    else {
        return $self->SUPER::properties(@_);
    }
}

sub settable_properties {
    my $self = shift;

    if (defined $self->{special}) {
        return ();
    }

    else {
        return $self->SUPER::settable_properties(@_);
    }
}

sub path {
    my $self = shift;
    return $self->get_property('path');
}

sub basename {
    my $self = shift;
    return $self->get_property('basename');
}

sub dirname {
    my $self = shift;
    return $self->get_property('dirname');
}

sub object_type {
    my $self = shift;
    return $self->get_property('object_type');
}

sub get_property {
    my $self = shift;

#    use Data::Dumper;
#    print STDERR Dumper($self);

    if (defined $self->{special}) {
        my $key = shift;

        $key =~ /^object_type$/ 
            and return $self->{special}{type};
        $key =~ /^basename$/    
            and return $self->basename_of_path($self->{special}{path});
        $key =~ /^dirname$/
            and return $self->dirname_of_path($self->{special}{path});
        $key =~ /^path$/
            and return $self->{special}{path};
        return $self->{special}{properties}{$key};
    }

    else {
        return $self->SUPER::get_property(@_);
    }
}

sub set_property {
    my $self = shift;

    if (defined $self->{special}) {
        Contentment::Exception->throw(
            message => 'Cannot set properties here.',
        );
    }

    else {
        return $self->SUPER::set_property(@_);
    }
}

sub rename {
    my $self = shift;

    if (defined $self->{special}) {
        Contentment::Exception->throw(
            message => 'Cannot rename this.',
        );
    }

    else {
        return $self->SUPER::rename(@_);
    }
}

sub move {
    my $self = shift;

    if (defined $self->{special}) {
        Contentment::Exception->throw(
            message => 'Cannot move this.',
        );
    }

    else {
        return $self->SUPER::move(@_);
    }
}

sub copy {
    my $self = shift;

    if (defined $self->{special}) {
        Contentment::Exception->throw(
            message => 'Cannot copy this.',
        );
    }

    else {
        return $self->SUPER::copy(@_);
    }
}

sub remove {
    my $self = shift;

    if (defined $self->{special}) {
        Contentment::Exception->throw(
            message => 'Cannot remove this.',
        );
    }

    else {
        return $self->SUPER::remove(@_);
    }
}

sub is_readable {
    my $self = shift;

    if (defined $self->{special}) {
        return '';
    }

    else {
        return $self->SUPER::is_readable(@_);
    }
}

sub is_seekable {
    my $self = shift;

    if (defined $self->{special}) {
        return '';
    }

    else {
        return $self->SUPER::is_seekable(@_);
    }
}

sub is_writable {
    my $self = shift;

    if (defined $self->{special}) {
        return '';
    }

    else {
        return $self->SUPER::is_writable(@_);
    }
}

sub is_appendable {
    my $self = shift;

    if (defined $self->{special}) {
        return '';
    }

    else {
        return $self->SUPER::is_appendable(@_);
    }
}

sub open {
    my $self = shift;

    if (defined $self->{special}) {
        Contentment::Exception->throw(
            message => 'Cannot open this file. Use generate() instead.',
        );
    }

    else {
        return $self->SUPER::open(@_);
    }
}

sub content {
    my $self = shift;

    if (defined $self->{special}) {
        Contentment::Exception->throw(
            message => 'Cannot open this file. Use generate() instead.',
        );
    }

    else {
        return $self->SUPER::content(@_);
    }
}

sub has_children {
    my $self = shift;

    if (defined $self->{special}) {
        return 1 if @{ $self->{special}{children} };
    }

    else {
        return $self->SUPER::has_children(@_);
    }
}

sub child {
    my $self = shift;
    my $name = shift;

    if ($name eq '.') {
        return $self;
    }

    elsif ($name eq '..') {
        return $self->parent;
    }

    else {
        if (defined $self->{special}) {
            if (grep { $name eq $_ } @{ $self->{special}{children} }) {
                return $self->lookup($name);
            }

            else {
                return undef;
            }

        }

        else {
#            use Data::Dumper;
            my $child = $self->SUPER::child($name);
#            print STDERR Dumper($self, $child);
            return $child;
        }
    }
}

sub children_paths {
    my $self = shift;

#    my @paths;
#    if (defined $self->{special}) {
#        @paths = ('.', '..', @{ $self->{special}{children} });
#    }
#
#    else {
        my @paths = ('.', '..', map { $_->basename } $self->children);
#    }

#    use Data::Dumper;
#    print STDERR Dumper(\@paths);

    return @paths;
}

sub children {
    my $self = shift;

    if (defined $self->{special}) {
        return map { $self->lookup($_) } @{ $self->{special}{children} };
    }

    else {
        my @children = $self->SUPER::children(@_);

        my $path = $self->path;
        my $iter = Contentment::Hooks->call_iterator(
            'Contentment::VFS::simple');
        while ($iter->next) {
            my $handler_path = $iter->name;

            if ($path =~ m{^$handler_path}) {
                Contentment::Log->warning(
                    'Unreachable simple VFS handler %s found.',
                    [$handler_path]
                );
            }

            elsif ($handler_path =~ s{^$path}{}) {
                my ($child) = split m{/}, $handler_path;
                my $obj = $self->lookup($child);

#                use Data::Dumper;
#                print STDERR Dumper($obj);
#                print STDERR "Found $child ($obj) for $handler_path.\n";
                push @children, $obj;
            }
        }

        return @children;
    }
}

sub glob {
    my $self = shift;
#    print STDERR join(', ', @_),"\n";
    return $self->File::System::Object::glob(@_);
}

sub find {
    my $self = shift;
#    print STDERR join(', ', @_),"\n";
    return $self->File::System::Object::find(@_);
}

sub lookup {
    my $self = shift;
    my $path = $self->normalize_path(shift);

    if ($path eq '.' && defined $self->{special}) {
        return $self;
    }

    elsif ($path eq '..' && defined $self->{special}) {
        return $self->parent;
    }

    else {
        if (my $obj = $self->SUPER::lookup($path)) {
            return $obj;
        }

        else {
            return $self->_simple_lookup($path);
        }
    }
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

		Contentment::Log->debug('searching for alternate file %s', ["$copy.*"]);

		my @files = $self->glob("$copy.*");
		for my $source_file (@files) {
			if ($file = $self->lookup($source_file) and $file->has_content) {
				$result = $file;
				last;
			}
		}

        if (!$result && $copy ne $path) {
            Contentment::Log->debug('searching for alternate file %s', [$copy]);
            $result = $self->lookup($copy);
        }
	}

	return $result;
}

sub properties_hash {
    my $self = shift;

    return { 
        map { $_ => $self->get_property($_) } $self->properties
    };
}

=item $generator = $file_thing-E<gt>generator

Returns the generator which is capable of generating the file thing.

Returns C<undef> when C<has_content> is false.

=cut

sub generator {
	my $self = shift;

    # If it's a special file, return it's generator.
    if (defined $self->{special}) {
        return $self->{special}{generator};
    }

    # If there's no content, we provide no generator.
	$self->has_content or return undef;

    # We've already figured it out for this object. Return that one.
	defined $self->{generator} and return $self->{generator};

    # Run the hook handlers until we get a generator and use that
	my $iter = Contentment::Hooks->call_iterator('Contentment::VFS::generator');
	while ($iter->next) {
		my $generator = $iter->call($self);
		if ($generator) {
			Contentment::Log->debug('Matched file %s with generator %s', 
                [$self,$generator]);
			return $self->{generator} = $generator;
		}
	}

	Contentment::Log->warning(q(Couldn't match %s with a generator), [$self]);

	return undef;
}

#=item @files = $obj-E<gt>ancestors
#
#This is a handy method that returns the parent, grandparent, and so forth for the current object C<$obj>. The files are returned in order such that the ultimate parent is first and the nearest parent is last. (Handy for crumbtrail generation, etc.)
#
#Returns an empty list if the current object is the root.
#
#=cut
#
#sub ancestors {
#	my $self = shift;
#
#	return () if $self->is_root;
#	
#	my $file_path;
#	my $root = $self->root;
#	my @ancestors = $root;
#
#    Contentment::Exception->throw(
#        message => 'Root failure.'
#    ) unless $self->root;
#
#	my $orig_path = $self->path;
#	$orig_path =~ s/^\///;
#
#	for my $path (split /\//, $orig_path) {
#		$file_path .= "/$path";
#		my $file = $self->lookup($file_path)
#			or Contentment::Exception->throw(
#                   message => qq(Error looking up file "$file_path"),
#               );
#		push @ancestors, $file;
#	}
#
#	return @ancestors;
#}

=item $vfs-E<gt>add_layer($index, $filesystem)

Layers another file system object over the current file system. If you want to make the new layer top priority set C<$index> to 0. If you want it the lowest priority, set C<$index> to -1.

If the file system wrapped is not a L<File::System::Layered> object, it is made such an object with the current file system object made the only internal layer.

=cut

sub add_layer {
	my $self       = shift;
	my $index      = shift;
	my $filesystem = shift;

    my $root = $self->instance;

    # Calculate fsname for logging
	my $fsname;
	if (ref $filesystem eq 'ARRAY') {
		$fsname = 
            "$filesystem->[0]("
                .join(', ', @{$filesystem}[1 .. $#$filesystem])
           .")";
	} else {
		$fsname = ref $filesystem;
	}

    # Fetch the FS layers
	my @layers = $self->{fs}->get_layers;
	
    # If the index given is less than 0 turn it into an absolute index
	if ($index < 0) {
		$index = @layers + $index + 1;
	}

    # Log the action
	Contentment::Log->debug(
        "Adding new file system %s to index %d", [$fsname,$index]);

    # If necessary, recalculate the table layer used for mounting
    if ($index <= $root->{table_layer}) {
        ++$root->{table_layer};
    }

    # Push the layer back into the list
	splice @layers, $index, 0, $filesystem;
	$self->{fs}->set_layers(@layers);
}

=item $vfs-E<gt>get_layers

Lists the layers in the file system.

=cut

sub get_layers {
	my $self = shift;
    $self->{fs}->get_layers;
}

=item $vfs-E<gt>remove_layer($index)

Removes the layer found at the given C<$index>. Throws an exception if the file system isn't layered or there is only one layer left.

=cut

sub remove_layer {
	my $self = shift;
	my $index = shift;

    my $root = $self->instance;

    # Make sure they don't remove the table layer
    if ($index == $root->{table_layer}) {
        Contentment::Exception->throw(
            message => 'Cannot remove the original layer.',
        );
    }

    # On removal, indexes must be non-negative
    if ($index < 0) {
        Contentment::Exception->throw(
            message => 'On removal, the index must be non-negative.',
        );
    }

    # If necessary, Move the table layer
    if ($index < $root->{table_layer}) {
        --$root->{table_layer};
    }

    # Rip out the file system at the given index
    my @layers = $self->{fs}->get_layers;
    splice @layers, $index, 1;
    $self->{fs}->set_layers(@layers);
}

=item $vfs-E<gt>mount($path, $filesystem)

Mount a the given file system, C<$filesystem>, onto the given path, C<$path>.

See L<File::System::Table> for more details.

=cut

sub mount {
    my $self = shift;
    my @layers = $self->{fs}->get_layers;
    $layers[ $self->instance->{table_layer} ]->mount(@_);
}

=item @paths = $fs->mounts

Returns the list of all paths that have been mounted to.

See L<File::System::Table> for more details.

=cut

sub mounts {
    my $self = shift;
    my @layers = $self->{fs}->get_layers;
    $layers[ $self->instance->{table_layer} ]->mounts(@_);
}

=item $filesystem = $vfs-E<gt>unmount($path)

Unmount a given file system found at path, C<$path>. Returns the file system object that was unmounted.

See L<File::System::Table> for more details.

=cut

sub unmount {
    my $self = shift;
    my @layers = $self->{fs}->get_layers;
    $layers[ $self->instance->{table_layer} ]->unmount(@_);
}

=back

=head2 CONTEXT

This class adds the following methods to the context:

=over

=item $vfs = $context-E<gt>vfs

Returns the VFS object.

=cut

sub Contentment::Context::vfs {
    return Contentment::VFS->instance;
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::VFS::resolve

Handles the "Contentment::Response::resolve" handler. Looks for a file in the VFS to return as a component for rendering.

=cut

sub resolve {
	my $path    = shift;
    my $context = Contentment->context;
	my $vfs     = $context->vfs;

    # Default to the request path_info, if no $path argument is given
	unless ($path) {
		my $q = $context->cgi;
		$path = $q->path_info;
	}

    # Lookup the file at the given path
	my $file = $vfs->lookup($path);

    # If such a file exists and it's a directory...
	if ($file && $file->is_container) {

        # If the path ends in a "/", generate the index in that directory
		if ($path =~ /\/$/) {

            # If there is an index, generate it
            if (my $thing = $vfs->lookup_source($path)) {
                return $thing->generator;
            }

            # If there isn't an index, we didn't find anything.
            else {
                return undef;
            }
		} 
        
        # The path doesn't end in a "/", redirect them so that it does.
        else {
			return $context->response->redirect(
                "$path/", %{ $context->cgi->Vars }
            );
		}
	} 
    
    # We didn't find anything literally at that path, let's try by looking for
    # files with different suffixes.
    else {
        
        # A file with a different suffix does exist, use that.
        my $thing = $file || $vfs->lookup_source($path);
		if (defined $thing) {
            return $thing->generator;
        } 
        
        # We found nothing.
        else {
            return undef;
        }
	}
}

=head2 HOOKS

=over

=item Contentment::VFS::generator

The handlers for this hook are passed a single argument, a L<Contentment::VFS> object pointing to a particular path. The handler should return C<undef> if it is unable to provide a generator for that file. The handler should return a constructor generator for the file, if it can provide a generator. The hook stops when the first handler returns something other than C<undef>.

=item Contentment::VFS::simple

Used as a simple way of grafting on to the file system without having to implement a full blown L<File::System::Object> implementation. See L</"VFS HOOKS"> for additional information.

=back

=head1 SEE ALSO

L<File::System>, L<File::System::Other>, L<File::System::Passthrough>, L<Contentment::Generator::Plain>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
