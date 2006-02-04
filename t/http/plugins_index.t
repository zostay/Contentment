# vim: set ft=perl :

use strict;
use warnings;

use Test::More tests => 15;

SKIP: {
    eval "use Apache::TestRequest 'GET_BODY'";
    skip "Apache::Test is not install.", 15 if $@;

    my $body = GET_BODY('/plugins/index/list.txt');

    like($body, qr{^ - A}m);
    like($body, qr{^ - E}m);
    like($body, qr{^ - I}m);
    like($body, qr{^    - /index\.html}m);
    like($body, qr{^    - /cgi-bin/init\.yml}m);
    like($body, qr{^ - O}m);
    like($body, qr{^ - U}m);

    $body = GET_BODY('/plugins/index/search.txt');

    like($body, qr{^ - A}m);
    unlike($body, qr{^ - E}m);
    like($body, qr{^ - I}m);
    like($body, qr{^    - /index\.html}m);
    like($body, qr{^    - /cgi-bin/init\.yml}m);
    unlike($body, qr{^ - O}m);
    unlike($body, qr{^ - U}m);
    unlike($body, qr{^ - F}m);
}
