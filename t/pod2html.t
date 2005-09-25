# vim: set ft=perl :

use strict;
use Test::More tests => 4;

SKIP: {
	eval "use Apache::TestRequest 'GET_BODY'";
	skip "Apache::Test is not installed.", 5 if $@;

	my $body = GET_BODY('/pod.html');

	like($body, qr{<h1>NAME</h1>});
	like($body, qr{<p>Simple Test Case</p>});
	like($body, qr{<h1>DESCRIPTION</h1>});
	like($body, qr{<p>This is a test.</p>});
}
