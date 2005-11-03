# vim: set ft=perl :

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use Test::More tests => 10;

my $conf = Contentment->configuration;

SKIP: {
	eval "
		use Apache::Test ':withtestmore';
		use Apache::TestRequest;
	";
	skip "Apache::Test is not installed.", 10 if $@;

	my $data = GET_BODY('/list/plain_index.html');
	like ($data, qr(<title>\s*Index Test\s*-\s*$conf->{site_title}\s*</title>));
	for my $n (1 .. 9) {
		like ($data, qr(<a href="/list/$n\.html">Testing #$n</a>));
	}
}
