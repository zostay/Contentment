# vim: set ft=perl :

use strict;
use Contentment::Test;
use Test::More tests => 6;

my $body = GET('/generator.txt')->content;

like($body, qr/^GENERATOR IS/m);

like($body, qr/^kind = test/m);
like($body, qr/^foo = 1/m);
like($body, qr/^bar = baz/m);

like($body, qr/^BEGIN PLAIN\s+test\s+END/m);

like($body, qr/^BEGIN ARGS\s+test\s+END/m);
