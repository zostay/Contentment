# vim: set ft=perl :

use strict;
use Contentment::Test;
use Test::More tests => 1;

my $body = GET('/index.html')->content;

like($body, qr/welcome to /);
