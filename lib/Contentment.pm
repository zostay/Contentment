package Contentment;

use strict;
use warnings;

our $VERSION = '0.011_030';

use Carp;
use Contentment::Hooks;
use Contentment::Log;
use Contentment::MIMETypes;
use Contentment::Response;
use Contentment::Request;
use Cwd ();
use File::Spec;
use YAML ();

=head1 NAME

Contentment - Contentment is a Perl-based web content management system

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

	# Load Plugins Phase #1: Find the plugins.

	# Find the directory/directories to start searching for plugins.
	my @plugins_dir = ($global_init->{plugins_dir});
	@plugins_dir = ref($plugins_dir[0]) ? @{$plugins_dir[0]} : @plugins_dir;

	# Search these plugin directories for plugins that we have not seen yet.
	my %plugins;
	for my $plugins_dir (@plugins_dir) {
		opendir PLUGINS, $plugins_dir;
		while (my $plugin_dir = readdir PLUGINS) {
			my $full_plugin_dir = File::Spec->catdir($plugins_dir, $plugin_dir);

			# Ignore superfluous crap we find
			next unless -d $full_plugin_dir;
			next if $plugin_dir =~ /^\./;

			# If the directory doesn't have an init.yml, it ain't a plugin.
			my $init_config = File::Spec->catfile($full_plugin_dir, 'init.yml');
			unless (-f $init_config) {
				Contentment::Log->warning("Directory $full_plugin_dir doesn't have an init.yml, skipping as if not a plugin.");
				next;
			}

			# Try to load the settings.
			Contentment::Log->info("Loading plugin configuration $init_config");
			my $init = eval { YAML::LoadFile($init_config); };

			# If we failed, log it, but continue.
			if ($@) {
				Contentment::Log->error("Failed loading plugin configuration $init_config: $@");
				next;
			}

			# It must have a name
			unless ($init->{name}) {
				Contentment::Log->error("Plugin configuration $init_config is missing the 'name' attribute. Skipping plugin.");
				next;
			}
			
			# It must have a version
			unless ($init->{version}) {
				Contentment::Log->error("Plugin configuraiton $init_config is missing the 'version' attribute. Skipping plugin.");
				next;
			}

			# Remember the plugin directory location.
			$init->{plugin_dir} = $full_plugin_dir;

			# Set the order to 0 if not given
			$init->{order} ||= 0;
			
			# Use the installed init settings, if already installed. This allows
			# the user to change the way the plugin operates after installation.
			eval {
				my $stored_init = Contentment::Setting->instance->{"Contentment::Plugin::$init->{name}"};
				if ($stored_init && $stored_init->{version} eq $init->{version}) {
					Contentment::Log->debug("Using stored init for plugin %s %s", [$init->{name},$init->{version}]);
					$init = $stored_init;
				}
			};

			# Remember we loaded this.
			$plugins{$init->{name}} = $init;
		}
		closedir PLUGINS;
	}

	# Load Plugins Phase #2: Load the plugins.
	
	# Sort the plugins by their given load order.
	# TODO Make this a "depends" instead.
	my @plugins = sort { $a->{order} <=> $b->{order} } values %plugins;
	
	# Load each plugin in order
	for my $plugin (@plugins) {
		Contentment::Log->info("Loading plugin %s %s", [$plugin->{name}, $plugin->{version}]);
		eval { Contentment->load_plugin($plugin) };
		Contentment::Log->error("Failed loading plugin %s: %s", [$plugin->{name},$@]) if $@;
	}

	# Load Plugind Phase #3: Install/Upgrade/Remove the plugins.

	# Get ready to figure out what's installed and not
	my $settings = Contentment::Setting->instance;
	my $installed = $settings->{'Contentment::installed'};

	# Check each plugin to see if it is installed. If not, install it.
	my $iter = Contentment::Hooks->call_iterator('Contentment::install');
	while ($iter->next) {
		# Skip install if it's installed.	
		if ($installed && $installed->{$iter->name}) {
			Contentment::Log->debug("Skipping install of %s as version %s is already here.", [$iter->name,$installed->{$iter->name}]);
			next;
		}

		# Run the handler.
		my $plugin = $plugins{$iter->name};
		eval {
			$iter->call($plugin);
		};

		# Check for errors
		if ($@) {
			Contentment::Log->error("Error installing plugin %s %s: %s", [$iter->name,$plugin->{version},$@]);
		}

		# Record the installed version, if we can.
		Contentment::Log->info("Installed plugin %s %s",[$iter->name,$plugin->{version}]);
		$installed->{$iter->name} = $plugin->{version};
		$settings->{'Contentment::Plugin::'.$iter->name} = $plugin;
	}

	# Now check for upgrades.
	$iter = Contentment::Hooks->call_iterator('Contentment::upgrade');
	while ($iter->next) {
		my $plugin = $plugins{$iter->name};
		
		# If the installed version is the same as this version, skip this
		# handler.
		next if $installed->{$iter->name} == $plugin->{version};

		# Run the handler.
		$iter->call($settings->{'Contentment::Plugin::'.$iter->name}, $plugin);

		# Note that it's now installed and record the version.
		Contentment::Log->info("Upgraded plugin %s from %s to %s",[$iter->name,$installed->{$iter->name},$plugin->{version}]);
		$installed->{$iter->name} = $plugin->{version};
        $settings->{'Contentment::Plugin::'.$iter->name} = $plugin;
	}

	# Save the install/upgrade settings.
	$settings->{'Contentment::installed'} = $installed;

	# Now that all is installed, initialize all the begin handlers
	Contentment::Log->debug("Calling hook Contentment::begin");
	Contentment::Hooks->call('Contentment::begin');
}

sub load_plugin {
	my $class       = shift;
	my $plugin_init = shift;
	my $plugin_dir  = $plugin_init->{plugin_dir};

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
		die qq(Couldn't use "$use": $@) if $@;
	}

	# Check for a variable named "hooks" and setup each hook.
	if ($plugin_init->{hooks}) {
		while (my ($hook, $arg) = each %{ $plugin_init->{hooks} }) {
			no strict 'refs';
			if (ref $arg) {
				Contentment::Log->debug("Registering hook %s for plugin %s with order %d", [$hook,$plugin_init->{name},$arg->{order}||0]);
				Contentment::Hooks->register(
					hook  => $hook, 
					code  => \&{$arg->{sub}}, 
					order => $arg->{order},
					name  => $arg->{name} || $plugin_init->{name},
				);
			} else {
				Contentment::Log->debug("Registering hook %s for plugin %s with default order", [$hook,$plugin_init->{name}]);
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
		Contentment::Log->debug("Registering dummy hook Contentment::install for plugin %s", [$plugin_init->{name}]);
		Contentment::Hooks->register(
			hook => 'Contentment::install',
			code => sub {},
			name => $plugin_init->{name},
		);
	}

	# Create empty upgrade hook so upgrades work properly
	unless ($plugin_init->{hooks}{'Contentment::upgrade'}) {
		Contentment::Log->debug("Registering dummy hook Contentment::upgrade for plugin %s", [$plugin_init->{name}]);
		Contentment::Hooks->register(
			hook => 'Contentment::upgrade',
			code => sub {},
			name => $plugin_init->{name},
		);
	}


	# Create empty remove hook so removals work properly
	unless ($plugin_init->{hooks}{'Contentment::remove'}) {
		Contentment::Log->debug("Registering dummy hook Contentment::remove for plugin %s", [$plugin_init->{name}]);
		Contentment::Hooks->register(
			hook => 'Contentment::remove',
			code => sub {},
			name => $plugin_init->{name},
		);
	}
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

=item Contentment-E<gt>handle_fast_cgi

This passes control to the appropriate request and response objects to handle FastCGI connections.

See L<Contentment::Request> and L<Contentment::Response> for more information.

=cut

sub handle_fast_cgi {
    # Loop through each FastCGI connection we get. Other than this loop,
    # everything else is just like CGI!
    while (Contentment::Request->begin_fast_cgi) {
        # Handle the request using regular CGI logic
        Contentment::Response->handle_cgi;

        # Finish up using the regular CGI logic
        Contentment::Request->end_fast_cgi;
    }
}

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
