package Contentment;

use strict;
use warnings;

our $VERSION = '0.011_031';

use Carp;
use Contentment::Hooks;
use Contentment::Log;
use Contentment::MIMETypes;
use Contentment::Response;
use Contentment::Request;
use Cwd ();
use File::Spec;
use List::Util qw( reduce );
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

# %plugins = _find_plugins()
#
# Loads all the plugin init.yml files and stores those as the values of the
# %plugins hash. The keys will be set to the value of the "name" key in the
# init.yml file.
#
sub _find_plugins {
	# We assume the the directory the CGI is running in is the current working
	# directory. We assume we will find a file named "init.yml" there that will
	# contain the initial configuration for Contentment.
	my $cwd         = Cwd::getcwd;
	my $init_config = File::Spec->catfile($cwd, 'init.yml');
	$global_init    = YAML::LoadFile($init_config);

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

    return %plugins;
}

# _resolve_dependencies(\%plugins)
#
# Takes the %plugins hash and determines the appropriate order for the plugins
# to be dealt with. Dependencies are figured for just load order.
#
# Basically, any order explicitly set will be kept as is, but any plugin that
# has a dependency on something else will be sure to have an order at least one
# greater than the order of all its dependencies.
#
sub _resolve_dependencies {
    my $plugins = shift;

    my $plugin;

    # Normalize depends_on
    for $plugin (values %$plugins) {
        if (defined $plugin->{depends_on} && !ref $plugin->{depends_on}) {
            $plugin->{depends_on} = [ $plugin->{depends_on} ];
        }

        if (!defined $plugin->{depends_on}) {
            $plugin->{depends_on} = [];
        }
    }

    # Delete any plugin that has a dependency that doesn't exist.
    my $changed = 1;
    while ($changed) {
        $changed = 0;

        for $plugin (values %$plugins) {
            for my $dependency (@{ $plugin->{depends_on} }) {
                if (!defined $plugins->{ $dependency }) {
                    Contentment::Log->warning(
                        "Plugin $plugin->{name} requires unavailable ",
                        "dependency $dependency. Will not load.",
                    );
                    delete $plugins->{ $plugin->{name} };

                    # Iterate again to cascade to additional dependencies.
                    $changed++;
                }
            }

        }
    }

    # Find all plugins without a set order and without dependencies and set the
    # order to 0.
    my (@ordered, @free);
    for $plugin (values %$plugins) {
        if (defined $plugin->{order}) {
            push @ordered, $plugin;
        }

        elsif (!@{ $plugin->{depends_on} }) {
#            print STDERR "Setting $plugin->{name} to 0.\n";
            $plugin->{order} = 0;
            push @ordered, $plugin;
        }

        else {
            push @free, $plugin;
        }
    }

    # Loop until there are no more @free
    while (@free) {
        # Loop while @free is changing
        my $free_size = 0;
        while ($free_size != @free) {
            $free_size = @free;

            # Loop through remaining untouched plugins
            my @new_free;
            for $plugin (@free) {
                # Skip this one if it already has an order (which can happen if
                # the LOOP_BREAKER is invoked below).
                next if defined $plugin->{order};

                # Determine if all dependencies have an order, and if so, pick
                # the maximum:
                my $max 
                    = reduce { !defined $a || !defined $b ? undef
                             : $a > $b                    ? $a 
                             :                              $b }
                      map    { $plugins->{$_}{order} }
                      @{ $plugin->{depends_on} };

                # If all orders defined, set this order to the max + 1
                if (defined $max) {
#                    print STDERR "Setting $plugin->{name} to $max + 1\n";
                    $plugin->{order} = $max + 1;
                }

                # Otherwise, wait for the next iteration
                else {
#                    print STDERR "Not ordering $plugin->{name} ( ",
#                        join(' ', @{ $plugin->{depends_on} }), " )\n";
                    push @new_free, $plugin;
                }
            }

            @free = @new_free;
        }

        # If there are any left, we need to break a loop.
        #
        # For each free node, check to see if it is in a loop. (It is possible
        # for a free node to be dependent on a loop instead.)
        LOOP_BREAKER: 
        for $plugin (@free) {
            
            my (@open, %closed);
            
            # This is a list of nodes left to search.
            @open = @{ $plugin->{depends_on} };

            # The list of nodes already passed.
            $closed{ $plugin->{name} }++;

            # Keep searching until we've exhausted the open list.
            while (my $dependency = pop @open) {
                
                # The node we're searching was already hit: it is in a loop.
                if ($closed{ $dependency }) {
                    # Note the problem in the log.
                    Contentment::Log->error(
                        "Detected a depdency loop in $dependency plugin."
                    );

                    # We cannot resolve a loop, so we will just set the looping
                    # dependency to order = 0 and hope that's good enough.
                    $plugins->{ $dependency }{order} = 0;

                    # This should allow us to clear up this loop
                    last LOOP_BREAKER;
                }
            }
        }
    }

    # Log the orders found
    for my $plugin (values %$plugins) {
        Contentment::Log->debug(
            "Order $plugin->{name} = $plugin->{order} ( ",
            join(' ', @{ $plugin->{depends_on} })," )",
        );
    }
}

# _load_plugins(\%plugins)
#
# Loads the Perl modules associated with the plugin.
sub _load_plugins {
    my $plugins = shift;

	# Sort the plugins by their given load order.
	my @plugins = sort { $a->{order} <=> $b->{order} } values %$plugins;
	
	# Load each plugin in order
	for my $plugin (@plugins) {
		Contentment::Log->info("Loading plugin %s %s", [$plugin->{name}, $plugin->{version}]);
		eval { Contentment->load_plugin($plugin) };
		Contentment::Log->error("Failed loading plugin %s: %s", [$plugin->{name},$@]) if $@;
	}
}

# _install_plugins(\%plugins)
#
# Find new plugins that need to be installed and install them.
#
sub _install_plugins {
    my $plugins = shift;

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
		my $plugin = $$plugins{$iter->name};
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

	# Save the install settings.
	$settings->{'Contentment::installed'} = $installed;
}

sub _upgrade_plugins {
    my $plugins = shift;

	# Get ready to figure out what's installed and not
	my $settings = Contentment::Setting->instance;
	my $installed = $settings->{'Contentment::installed'};

	# Now check for upgrades.
	my $iter = Contentment::Hooks->call_iterator('Contentment::upgrade');
	while ($iter->next) {
		my $plugin = $$plugins{$iter->name};
		
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

	# Save the upgrade settings.
	$settings->{'Contentment::installed'} = $installed;
}


=item Contentment-E<gt>begin

Perform the initialization tasks for Contentment. Including running all hooks registered for "C<Contentment::begin>".

=cut

sub begin {
	# Plugins Phase #1: Find the plugins.
    my %plugins = _find_plugins();

    # Plugins Phase #2: Sort out dependencies.
    _resolve_dependencies(\%plugins);

	# Plugins Phase #3: Load the plugins.
    _load_plugins(\%plugins);
	
	# Plugins Phase #4: Install plugins.
    _install_plugins(\%plugins);

    # Plugins Phase #5: Upgrade plugins.
    _upgrade_plugins(\%plugins);

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
