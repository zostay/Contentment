# vim: set ft=perl :

use strict;
use Test::More tests => 3;

SKIP: {
	eval "use Apache::TestRequest 'GET'";
	skip "Apache::Test is not installed.", 3 if $@;

	my $res = GET('/perl.txt');
	my $body = $res->content;

	# test that the string start right, since CGI usually adds "; encoding=..."
	# on to the end
	like($res->header('Content-Type'), qr{^text/plain});
	like($body, qr/^Hello World!/m);
	like($body, qr{^path = /perl\.pl}m);
}
