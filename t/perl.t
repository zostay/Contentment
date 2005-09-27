# vim: set ft=perl :

use strict;
use Test::More tests => 2;

SKIP: {
	eval "use Apache::TestRequest 'GET_BODY'";
	skip "Apache::Test is not installed.", 1 if $@;

	my $body = GET_BODY('/perl.txt');

	like($body, qr/^Hello World!/m);
	like($body, qr{^path = /perl\.pl}m);
}
