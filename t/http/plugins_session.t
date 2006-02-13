# vim: set ft=perl :

use strict;
use Contentment::Test;
use Test::More tests => 1;

GET('/plugins/session/session1.txt');

my $body = GET('/plugins/session/session2.txt')->content;

like($body, qr/^foo = 1$/);
