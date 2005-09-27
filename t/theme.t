# vim: set ft=perl :

use strict;
use Test::More tests => 5;

SKIP: {
	eval "use Apache::TestRequest 'GET_BODY'";
	skip "Apache::Test is not installed.", 1 if $@;

	my $body = GET_BODY('/theme.html');

	like($body, qr{^/themes is a directory}m);
	like($body, qr{^/themes/default is a directory}m);
	like($body, qr{^/themes/default/text is a directory}m);
	like($body, qr{^/themes/default/text/html is a directory}m);
	like($body, qr{^/themes/default/text/html/top\.pl is a file}m);
}
