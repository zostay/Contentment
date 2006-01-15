# vim: set ft=perl :

use strict;
use Test::More tests => 6;

SKIP: {
    eval "use Apache::TestRequest 'GET_BODY'";
    skip "Apache::Test is not installed.", 1 if $@;

    my $body = GET_BODY('/generator.txt');

    like($body, qr/^GENERATOR IS/m);
    
    like($body, qr/^kind = test/m);
    like($body, qr/^foo = 1/m);
    like($body, qr/^bar = baz/m);

    like($body, qr/^BEGIN PLAIN\s+test\s+END/m);

    like($body, qr/^BEGIN ARGS\s+test\s+END/m);
}
