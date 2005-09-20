package Contentment;

use strict;
use warnings;

our $VERSION = 0.011_004;

use Carp;
use Contentment::Hooks;
use Contentment::Log;
use Contentment::Response;
use Contentment::Request;
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
	my %plugins;
	opendir PLUGINS, $plugins_dir;
	while (my $plugin_dir = readdir PLUGINS) {
		my $full_plugin_dir = File::Spec->catdir($plugins_dir, $plugin_dir);

		# Ignore superfluous crap we find
		next unless -d $full_plugin_dir;
		next if $plugin_dir =~ /^\./;

		# Load the initial configuration that is supposed to be in every plugin or
		# we just won't load it (assuming another non-plugin directory got in here
		# for some reason).
		my $init_config = File::Spec->catfile($full_plugin_dir, 'init.yml');
		next unless -f $init_config;
		Contentment::Log->info("Loading plugin configuration $init_config");
		my $init        = eval { YAML::LoadFile($init_config); };
		if ($@) {
			Contentment::Log->error("Failed loading plugin configuration $init_config: $@");
			next;
		}

		push @plugins, [ $full_plugin_dir, $init ];
	}
	closedir PLUGINS;

	# Now that we have the plugin initializers, we need to sort them by the
	# "order" variable in the file and load each plugin.
	@plugins = sort { $a->[1]{order} <=> $b->[1]{order} } @plugins;

	# Load each plugin in order
	for my $plugin (@plugins) {
		Contentment::Log->info("Loading plugin %s %s", [$plugin->[1]{name}, $plugin->[1]{version}]);
		eval { Contentment->load_plugin(@$plugin) };
		Contentment::Log->error("Failed loading plugin %s: %s", [$plugin->[0],$@]) if $@;
	}

	# Check each plugin to see if it is installed. If not, install it.
	my $settings = Contentment::Setting->instance;
	my $iter = Contentment::Hooks->call_iterator('Contentment::install');
	while ($iter->next) {
		# Since we store information in Contentment::Setting and it might not be
		# installed yet, check for installation and load the settings if it is.
		my $installed_version;
		if (Contentment::Setting->installed) {
			$installed_version = $settings->{'Contentment::installed::'.$iter->name} || 0;
		}
	
		# If Contentment::Setting is installed, check the version. If it's
		# installed, skip this handler.
		next if $installed_version;

		# Run the handler.
		my $plugin = Contentment->loaded_plugin($iter->name);	
		$iter->call($plugin);

		# Note that it's now installed and record the version.
		if (Contentment::Setting->installed) {
			Contentment::Log->info("Installed plugin ",$iter->name," $plugin->{version}");
			$settings->{'Contentment::installed::'.$iter->name} = $plugin->{version}
		} else {
			Contentment::Log->warning("Installed plugin ",$iter->name," $plugin->{version}. Settings not yet available for recording. Installation will probably run twice.");
		}
	}

	# Now check for needed upgrades. We assume Contentment::Setting is now
	# loaded and $installed is set to the right thing.
	$iter = Contentment::Hooks->call_iterator('Contentment::upgrade');
	while ($iter->next) {
		my $plugin = Contentment->loaded_plugin($iter->name);
		my $installed_version = $settings->{'Contentment::installed::'.$iter->name} || 0;
		
		# If the installed version is the same as this version, skip this
		# handler.
		next if $installed_version == $plugin->{version};

		# Run the handler.
		$iter->call($plugin);

		# Note that it's now installed and record the version.
		Contentment::Log->info("Upgraded plugin ",$iter->name," from $installed_version to $plugin->{version}");
		$settings->{'Contentment::installed::'.$iter->name} = $plugin->{version};
	}

	# Now that all is installed, initialize all the begin handlers
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
		map { Contentment::Log->debug("%s: use lib %s", [$plugin_dir,$_]); $_ }
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
	for my $use (@uses) {
		Contentment::Log->debug("%s: use %s", [$plugin_dir,$use]);
		eval "use $use";
		die $@ if $@;
	}

	# Check for a variable named "hooks" and setup each hook.
	if ($plugin_init->{hooks}) {
		while (my ($hook, $arg) = each %{ $plugin_init->{hooks} }) {
			no strict 'refs';
			if (ref $arg) {
				Contentment::Hooks->register(
					hook  => $hook, 
					code  => \&{$arg->{sub}}, 
					order => $arg->{order},
					name  => $arg->{name} || $plugin_init->{name},
				);
			} else {
				Contentment::Hooks->register(
					hook => $hook, 
					code => \&{$arg},
					name => $plugin_init->{name},
				);
			}
		}
	}

	# Create empty install hook so installation works properly
	unless ($plugin_init->{hooks}{'Contentment::install'}) {
		Contentment::Hooks->register(
			hook => 'Contentment::install',
			code => sub {},
			name => $plugin_init->{name},
		);
	}

	# Create empty upgrade hook so upgrades work properly
	unless ($plugin_init->{hooks}{'Contentment::upgrade'}) {
		Contentment::Hooks->register(
			hook => 'Contentment::upgrade',
			code => sub {},
			name => $plugin_init->{name},
		);
	}

	# Create empty remove hook so removals work properly
	unless ($plugin_init->{hooks}{'Contentment::remove'}) {
		Contentment::Hooks->register(
			hook => 'Contentment::remove',
			code => sub {},
			name => $plugin_init->{name},
		);
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
	confess "Missing required argument 'name'." unless $name;
	return $plugins{$name};
}

=item Contentment-E<gt>handle_cgi

This passes control to the appropriate request and response objects.

See L<Contentment::Request> and L<Contentment::Response> for more information.

=cut

sub handle_cgi {
	Contentment::Request->begin_cgi;
	Contentment::Response->handle_cgi;
	Contentment::Request->end_cgi;
}

=item Contentment-E<gt>handle_fcgi

Not yet implemented.

=item Contentment-E<gt>handle_lwp

Not yet implemented.

=item Contentment-E<gt>handle_mod_perl

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

This is a named hook. The name is used to determine which plugin configuration to pass the install handler. It should match the "name" setting in F<init.yml> for the plugin.

These handlers are passed a single argument, but no special input, and should not output anything. The special argument is the data loaded from F<init.yml>.

=item Contentment::begin

These handlers are passed no arguments, no special input, and should not output anything.

=item Contentment::end

These handlers are passed no arguments, no special input, and should not output anything.

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
