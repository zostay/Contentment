# vim: set ft=perl :

use strict;
use Test::More tests => 6;

SKIP: {
	eval "use Apache::TestRequest 'GET_BODY'";
	skip "Apache::Test is not installed.", 6 if $@;

	my $body = GET_BODY('/plugins/theme/theme.html');

	like($body, qr{<div id="content">\s*Hello Theme!});
	like($body, qr{^/themes is a directory}m);
	like($body, qr{^/themes/default is a directory}m);
	like($body, qr{^/themes/default/text is a directory}m);
	like($body, qr{^/themes/default/text/html is a directory}m);
	like($body, qr{^/themes/default/text/html/top\.tt2 is a file}m);
}
