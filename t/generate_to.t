# vim: set ft=perl :

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use Test::More tests => 1;

my $conf = Contentment->configuration;

SKIP: {
	eval "
		use Apache::Test ':withtestmore';
		use Apache::TestRequest;
	";
	skip "Apache::Test is not installed.", 1 if $@;

	eval "
		use Pod::Simple;
	";
	skip "Pod::Simple is not installed.", 1 if $@;

	my $data = GET_BODY('/generate_to.html');
	like ($data, qr{<h1>Generate To Test</h1>});
}
