package Contentment;

use strict;
use warnings;

our $VERSION = 0.011_001;

use Contentment::Hooks;
use Cwd ();
use File::Spec;
use YAML ();

=head1 NAME

Contentment - Contentment is a Perl-based web contentment management system

=head1 DESCRIPTION

=head2 METHODS

=over

=item $global_init = Contentment-E<gt>global_configuration

Returns the global initializer configuration. This is stored in F<init.yml> in the same directory as the CGI script, as of this writing.

The C<$global_init> should be a reference to a hash.

=cut

my $global_init;
sub global_configuration {
	return $global_init;
}

=item Contentment-E<gt>begin

Perform the initialization tasks for Contentment. Including running all hooks registered for "C<Contentment::begin>".

=cut

sub begin {
	# TODO Determine if assuming the cgi-bin is the cwd is a good idea.
	# We assume the the directory the CGI is running in is the current working
	# directory. We assume we will find a file named "init.yml" there that will
	# contain the initial configuration for Contentment.
	my $cwd         = Cwd::getcwd;
	my $init_config = File::Spec->catfile($cwd, 'init.yml');
	$global_init    = YAML::LoadFile($init_config);

	# Use the initial configuration to find the plugins directory. Cycle through
	# every sub-directory and load the plugin initializer files.
	my $plugins_dir = $global_init->{plugins_dir};
	my @plugins;
	opendir PLUGINS, $plugins_dir;
	while (my $plugin_dir = readdir PLUGINS) {
		# Ignore superfluous crap we find
		next unless -d $plugin_dir;

		# Load the initial configuration that is supposed to be in every plugin or
		# we just won't load it (assuming another non-plugin directory got in here
		# for some reason).
		my $init_config = File::Spec->catfile($plugin_dir, 'init.yml');
		next unless -f $init_config;
		my $init        = YAML::LoadFile($init_config);

		push @plugins, [ File::Spec->catdir($plugins_dir, $plugin_dir), $init ];
	}
	closedir PLUGINS;

	# Now that we have the plugin initializers, we need to sort them by the
	# "order" variable in the file and load each plugin.
	my @plugins = sort { $a->[1]{order} <=> $b->[1]{order} } @plugins;

	# Load each plugin in order
	for my $plugin (@plugins) {
		eval { Contentment->load_plugin(@$_) };
		Contentment::Log->error("Failed loading plugin $plugin: $@");
	}

	# Install/upgrade plugins and then "begin". The difference between these two
	# hooks is semantic. Put stuff that installs your plugin permanently in
	# "Contentment::install" but put stuff that runs every time at system
	# startup in "Contentment::begin". These might be split and made a little
	# smarter in the future, but I don't foresee such a thing at this time.
	Contentment::Hooks->call('Contentment::install');
	Contentment::Hooks->call('Contentment::begin');
}

my %plugins;
sub load_plugin {
	my $class       = shift;
	my $plugin_dir  = shift;
	my $plugin_init = shift;

	# Check for a variable named "use_lib" and add each of the listed
	# directories (relative to $plugin_dir) to the library list.
	my @use_libs;
	if (ref $plugin_init->{use_lib}) {
		@use_libs = @{ $plugin_init->{use_lib} };
	} else {
		@use_libs = ( $plugin_init->{use_lib} );
	}
	push @INC, 
		map { Contentment::Log->debug("$plugin_dir: use lib $_") }
		map { File::Spec->file_name_is_absolute($_) ? 
				$_ : 
				File::Spec->catdir($plugin_dir, $_) }
		@use_libs;

	# Check for a variable named "use" and load each Perl module listed or die.
	my @uses;
	if (ref $plugin_init->{use}) {
		@uses = @{ $plugin_init->{use} };
	} else {
		@uses = ( $plugin_init->{use} );
	}
	foreach (@uses) {
		Contentment::Log->debug("$plugin_dir: use $_");
		eval "use $_";
		die $@ if $@;
	}

	# Check for a variable named "hooks" and setup each hook.
	if ($plugin_init->{hooks}) {
		while (my ($hook, $arg) = each %{ $plugin_init->{hooks} }) {
			if (ref $arg) {
				Contentment::Hooks->register($hook, *{$arg->{sub}}, $arg->{order});
			} else {
				Contentment::Hooks->register($hook, $arg);
			}
		}
	}

	$plugins{$plugin_init->{name}} = $plugin_init;
}

=item @plugins = Contentment-E<gt>loaded_plugins

Returns a list of the initializer configuration for all the plugins that loaded successfully.

=cut

sub loaded_plugins {
	return values %plugins;
}

=item $plugin_init = Contentment-E<gt>loaded_plugin($name)

Returns the initializer configuration for the plugin named C<$name>. The return C<$plugin_init> should be a reference to a hash.

=cut

sub loaded_plugin {
	my $class = shift;
	my $name  = shift;
	return $plugins{$name};
}

=item Contentment-E<gt>handle_cgi

This passes control to the appropriate request and response objects.

See L<Contentment::Request> and L<Contentment::Response> for more information.

=cut

=item Contentment-E<gt>handle_fcgi

Not yet implemented.

=item Contentment-E<gt>end

Performs final shutdown of the Contentment system. This calls the "L<Contentment::end>" hooks.

=cut

sub end {
	Contentment::Hooks->call('Contentment::end');
}

=back

=head2 HOOKS

=over

=item Contentment::install

These hooks are passed no arguments, no special input, and should not output anything.

=item Contentment::begin

These hooks are passed no arguments, no special input, and should not output anything.

=item Contentment::end

These hooks are passed no arguments, no special input, and should not output anything.

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
