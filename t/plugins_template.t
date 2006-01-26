# vim: set ft=perl :

use strict;
use Test::More tests => 3;

SKIP: {
	eval "use Apache::TestRequest 'GET_BODY'";
	skip "Apache::Test is not installed.", 3 if $@;

	my $body = GET_BODY('/plugins/template/template.txt');

	like($body, qr/^Hello World!/m);
	like($body, qr{^path = /plugins/template/template\.tt2}m);
	like($body, qr{^INCLUDE = foo}m);
}
