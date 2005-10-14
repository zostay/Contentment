# vim: set ft=perl :

use strict;
use Test::More tests => 3;

SKIP: {
	eval "use Apache::TestRequest 'GET'";
	skip "Apache::Test is not installed.", 1 if $@;

	my $res = GET('/perl.txt');
	my $body = $res->content;

	is($res->header('Content-Type', 'plain/text');
	like($body, qr/^Hello World!/m);
	like($body, qr{^path = /perl\.pl}m);
}
