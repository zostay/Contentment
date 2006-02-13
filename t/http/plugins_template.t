# vim: set ft=perl :

use strict;
use Contentment::Test;
use Test::More tests => 3;

my $body = GET('/plugins/template/template.txt')->content;

like($body, qr/^Hello World!/m);
like($body, qr{^path = /plugins/template/template\.tt2}m);
like($body, qr{^INCLUDE = foo}m);
