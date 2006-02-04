# vim: set ft=perl :

use strict;
use Test::More tests => 1;

SKIP: {
	eval "use Apache::TestRequest 'GET_BODY'";
	skip "Apache::Test is not installed.", 1 if $@;

	my $body = GET_BODY('/index.html');

	like($body, qr/welcome to /);
}
