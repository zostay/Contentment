package Contentment;

use strict;
use warnings;

use Carp;
use Contentment::Config;
use Contentment::VFS;
use Log::Log4perl ':easy';
use YAML 'LoadFile';

our $VERSION = '0.009_004';

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
$SIG{__WARN__} = sub { Log::Log4perl::get_logger->warn(dc(caller(1)),"@_")  };
$SIG{__DIE__}  = sub { eval { Log::Log4perl::get_logger->error("An error prevented Contentment from serving this request: @_\n ",scream) }; confess @_; };

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment - Contentment is a Mason/Perl-bsed CMS

=head1 DESCRIPTION

General configuration information and some general-purpose methods can be found in this module.

=over

=item $conf = Contentment->configuration

Reads the configuration files F<Contentment::Config::ETC_DIR/Contentment.defaults.conf> and F<Contentment::Config::ETC_DIR/Contentment.conf>.

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

=item my $result = Contentment->run_plugin($plugin, @args)

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

=item Contentment->call_hooks($dir, @args)

Run the appropriate generator on all files in F</content/hooks/$dir> and all subdirectories. The given C<@args> are passed each time.

Logs, but otherwise ignores, any errors that occur.

=cut

sub call_hooks {
	my $class = shift;
	my $dir   = shift;
	my $vfs   = Contentment::VFS->new;

	my $hook_dir = $vfs->lookup("/content/hooks/$dir");

	for my $file ($vfs->find(sub { shift->has_content }, $hook_dir)) {
		$file->generate(@_);
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
