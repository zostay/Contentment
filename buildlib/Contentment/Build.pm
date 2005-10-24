package Contentment::Build;

use strict;
use warnings;

our $VERSION = '0.05';

my $build_pkg = eval { require Apache::TestMB }
	? 'Apache::TestMB' : 'Module::Build';
our @ISA = $build_pkg;

use File::Path;

sub ACTION_test {
	my $self = shift;

	print "Creating test version of CGI script: t/htdocs/cgi-bin/contentment.cgi\n";

	open IN, 'htdocs/cgi-bin/contentment.cgi'
		or die "Cannot open htdocs/cgi-bin/contentment.cgi: $!";
	open OUT, '>t/htdocs/cgi-bin/contentment.cgi'
		or die "Cannot open t/htdocs/cgi-bin/contentment.cgi: $!";

	while (<IN>) {
		if (/^use Contentment;/) {
			print OUT qq{use lib '../../../blib/lib';\n};
            print OUT qq{use lib '../../lib';\n};
		}
		
		print OUT $_;
	}

	close IN;
	close OUT;

	$self->make_executable('t/htdocs/cgi-bin/contentment.cgi');

	$self->add_to_cleanup('t/htdocs/cgi-bin/contentment.cgi');

	$self->depends_on('code');
	$self->depends_on('run_tests');
	$self->depends_on('test_clean');
}

1
