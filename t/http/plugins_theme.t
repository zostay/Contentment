# vim: set ft=perl :

use strict;
use Contentment::Test;
use Test::More tests => 6;

my $body = GET('/plugins/theme/theme.html')->content;

like($body, qr{<div id="content">\s*Hello Theme!});
like($body, qr{^/themes is a directory}m);
like($body, qr{^/themes/default is a directory}m);
like($body, qr{^/themes/default/text is a directory}m);
like($body, qr{^/themes/default/text/html is a directory}m);
like($body, qr{^/themes/default/text/html/top\.tt2 is a file}m);
