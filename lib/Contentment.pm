package Contentment;

use strict;
use warnings;

#use Cache::FileCache;
use Cache::BaseCache;
use Cache::NullCache;
use Carp;
use Contentment::Config;
use Contentment::VFS;
use File::Temp;
use HTML::Mason::Request;
use Log::Log4perl ':easy';
use Symbol;
use YAML 'LoadFile';

our $VERSION = '0.009_018';

BEGIN {
	Log::Log4perl::easy_init($DEBUG);
}

sub dc { sprintf "(package %s) (file %s:line %d) (called %s)", @_ }
sub scream {
	my $i = 2;
	my $str;
	while (my @c = caller($i++)) {
		$str .= sprintf "\tFrom package %s (%s:%d) called %s\n", @c;
	}
	return $str;
}
$SIG{__WARN__} = sub { Log::Log4perl::get_logger->warn(dc(caller(1)), @_) };
$SIG{__DIE__}  = sub { eval { Log::Log4perl::get_logger->error("An error prevented Contentment from serving this request: @_\n ",scream) }; confess @_; };

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment - A Mason/Perl-based content management system

=head1 DESCRIPTION

General configuration information and some general-purpose methods can be found in this module.

=over

=item $conf = Contentment->configuration

Reads the configuration files F<ETC_DIR/Contentment.defaults.conf> and F<ETC_DIR/Contentment.conf>.

=cut

my %configuration;
sub configuration {
	unless (%configuration) {
		my $defaults_file = Contentment::Config::ETC_DIR.'/Contentment.defaults.conf';
		my $locals_file   = Contentment::Config::ETC_DIR.'/Contentment.conf';

		my ($defaults, $locals);
		eval {
			$defaults = LoadFile($defaults_file);
			$locals   = LoadFile($locals_file);
		};

		if ($@) { die "Error loading configuration: $@" }

		%configuration = (%$defaults, %$locals);

		# Initialize Log4perl
		if (my $log4perl_conf = $configuration{log4perl_conf}) {
			Log::Log4perl::init($log4perl_conf);
		} else {
			Log::Log4perl::easy_init($DEBUG);
			warn 'No log4perl.conf specified. Sending DEBUG and above to STDERR.';
		}
	}
	
	return \%configuration;
}

=item my $module = Contentment-E<gt>security

Fetch the configured security module.

=cut

sub security {
	return Contentment->configuration->{security_module};
}

=item my $context = Contentment-E<gt>context

This method returns the singleton object for L<Contentment::Context>.

=cut

our $context;
sub context {
	return $context if $context;

	Contentment->configuration;

	require Contentment::Context;
	require Contentment::Session;

	my $self = shift;
	my $args = shift || {};
	my @last_processed = @_;

	my $m = HTML::Mason::Request->instance;

	my $r = eval { $m->apache_req } || eval { $m->cgi_request };

	$context = Contentment::Context->new({
		url            => eval { $m->cgi_object->url } || undef,
		m              => $m,
		r              => $r,
		%$args,
	});

	Contentment::Session->open_session;

	return $context;
}

=item my $result = Contentment-E<gt>run_plugin($plugin, @args)

This method loads the given plugin C<$plugin> and runs it with the given C<@args> and returns the result C<$result>. The C<$plugin> variable is a complete package and method name. The method name is stripped and the package name is "used". Then, the method is called.

=cut

sub run_plugin {
	my $class = shift;
	my $plugin = shift;

	my ($package, $method) = $plugin =~ m/^(.*?)::(\w+)$/
		or die "Invalid plugin named $plugin";

	eval "use $package";
	warn "Problem loading plugin $package: $@" if $@;

	no strict 'refs';
	return $plugin->(@_);
}

=item $result = Contentment-E<gt>capture_streams($in, $out, $code, @args)

This is a helpful method for redirecting input and output for some bit of code. The C<$in> must be a readable file handle and C<$out> must be a writable file handle. The C<$code> is a CODE reference to be run.

First, the C<STDIN> file handle will be saved and then redirected to use C<$in>. The C<STDOUT> file handle will be saved and then redirected to use C<$out>.

Next, the C<$code> will be run in this environment and any additional arguments given will be based to the subroutine.

Finally, C<STDIN> and C<STDOUT> are restored and any result returned by C<$code> is returned. If an exception is raised while running C<$code>, then the file handles are safely restored before this method rethrows the exception.

=cut

sub capture_streams {
	my $class = shift;
	my $in    = shift;
	my $out   = shift;
	my $code  = shift;

	$log->is_debug &&
		$log->debug("Redirecting STDIN and STDOUT for capture.");

	my $tie_in  = UNIVERSAL::can($in,  'TIEHANDLE');
	my $tie_out = UNIVERSAL::can($out, 'TIEHANDLE');

	my ($save_in, $save_out);
	my ($save_in_fd, $save_out_fd);

	# Save/capture STDIN
	if ($tie_in) {
		$save_in = tied *STDIN;
		tie *STDIN, $in;
	} else {
		if (tied *STDIN) {
			$save_in = tied *STDIN;
			no warnings 'untie';
			untie *STDIN;
		}
		$save_in_fd = gensym;
		open($save_in_fd, '<&STDIN');
		open(STDIN, '<&='.fileno($in));
	}

	# Save/capture STDOUT
	if ($tie_out) {
		$save_out = tied *STDOUT;
		tie *STDOUT, $out;
	} else {
		if (tied *STDOUT) {
			$save_out = tied *STDOUT;
			no warnings 'untie';
			untie *STDOUT;
		}
		$save_out_fd = gensym;
		open($save_out_fd, '>&STDOUT');
		open(STDOUT, '>&='.fileno($out));
	}

	my $ofh = select STDOUT;

	# Run code within captured handles
	my $result;
	my $wantarray = wantarray;
	eval {
		if ($wantarray) {
			my @array = $code->(@_);
			$result = \@array;
		} else {
			$result = $code->(@_);
		}
	};

	my $ERROR = $@;

	select $ofh;

	# Restore STDOUT
	if ($tie_out) {
		if (defined $save_out) {
			tie *STDOUT, $save_out;
		} else {
			no warnings 'untie';
			untie *STDOUT;
		}
	} else {
		open(STDOUT, '>&='.fileno($save_out_fd));
		close($save_out_fd);
		
		if (defined $save_out) {
			tie *STDOUT, $save_out;
		}
	}

	# Restore STDIN
	if ($tie_in) {
		if (defined $save_in) {
			tie *STDIN, $save_in;
		} else {
			no warnings 'untie';
			untie *STDIN;
		}
	} else {
		open(STDIN, '<&='.fileno($save_in_fd));
		close($save_in_fd);

		if (defined $save_in) {
			tie *STDIN, $save_in;
		}
	}

	if ($ERROR) {
		die $ERROR;
	} else {
		return $wantarray ? @$result : $result;
	}
}

=item $cache = $context-E<gt>cache($namespace)

Returns a L<Cache::Cache> interface that can be used to cache generated output, etc.

=cut

my %cache;
sub cache {
	my $ctx = shift;
	my $namespace = shift;
	my $default_expires_in = shift || '3 hours';

	unless (defined $cache{$namespace}) {
		$cache{$namespace} = Cache::NullCache->new;
#		$cache{$namespace} = Cache::FileCache->new({
#			cache_root => Contentment->configuration->{temp_dir}."/cache",
#			namespace  => $namespace,
#			default_expires_in => $default_expires_in,
#			directory_umask => 022,
#		});
	}

	return $cache{$namespace};
}

=item Contentment-E<gt>call_hooks($dir, @args)

Run the appropriate generator on all files in F</content/hooks/$dir> and all subdirectories. The given C<@args> are passed each time.

The first hook will be given the input from the current C<STDIN> and the last hook will generate output straight to the current C<STDOUT>. In between, the previous hooks output to C<STDOUT> becomes the next hooks input on C<STDIN>.

Logs, but otherwise ignores, any errors that occur.

=cut

sub call_hooks {
	my $class = shift;
	my $dir   = shift;
	
#	my $cache = Contentment->cache('Contentment');
#	my @hooks;
#	if (my $hooks = $cache->get("hooks:$dir")) {
#		@hooks = @$hooks;
#		$log->is_debug &&
#			$log->debug("Cached ",scalar(@hooks)," hooks in '/content/hooks/$dir'.");
#	} else {
		my $vfs   = Contentment::VFS->new;

		my $hook_dir = $vfs->lookup("/content/hooks/$dir");

		unless ($hook_dir) {
			$log->is_debug &&
				$log->debug("Failed to find a directory named '/content/hooks/$dir'. No hooks to run.");
			return undef;
		}

		$log->is_debug &&
			$log->debug("Looking for hooks in '$hook_dir'");

		my @hooks = $hook_dir->find(sub { 
			my $self = shift;
			$self->has_content && $self->path !~ /\/\./ 
		});
		$log->is_debug &&
			$log->debug("Found ",scalar(@hooks)," hooks in '$hook_dir'.");

#		$cache->set("hooks:$dir" => \@hooks);
#	}

	my $out = File::Temp::tempfile;
	binmode $out;
	while (<STDIN>) {
		print $out $_;
	}
	seek $out, 0, 0;

	my ($in, $result);
	for (my $i = 0; $i <= $#hooks; ++$i) {
		$in  = $out;
		$out = File::Temp::tempfile;
		binmode $out;

		$result = eval {
			Contentment->capture_streams($in, $out, sub {
				$log->is_debug &&
					$log->debug("Executing hook '$hooks[$i]'");

				$hooks[$i]->generate(@_)
			})
		};

		if ($@) {
			$log->error("Error during call_hooks ($hooks[$i]): $@");
		}

		seek $out, 0, 0;
	}

	while (<$out>) {
		print STDOUT $_;
	}
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
