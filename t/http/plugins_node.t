# vim: set ft=perl :

use strict;
use warnings;
use Contentment::Test;
use Test::More tests => 17;

my $body = GET('/plugins/node/node.txt')->content;

like($body, qr{^node1 comment = Test 1}m);
like($body, qr{^node1 title = Testing 1}m);
like($body, qr{^node1 content = This is a test\.}m);

like($body, qr{^node2 comment = Test 2}m);
like($body, qr{^node2 title = Testing 2}m);
like($body, qr{^node2 content = This is another test\.}m);

like($body, qr{^node1 comment = Test 3}m);
like($body, qr{^node1 title = Testing 3}m);
like($body, qr{^node1 content = This is yet another test\.}m);

like($body, qr{^revision\[0\] comment = Test 1}m);
like($body, qr{^revision\[0\] title = Testing 1}m);
like($body, qr{^revision\[0\] content = This is a test\.}m);

like($body, qr{^revision\[1\] comment = Test 3}m);
like($body, qr{^revision\[1\] title = Testing 3}m);
like($body, qr{^revision\[1\] content = This is yet another test\.}m);

$body = GET('/test/Testing_3.txt')->content;
like($body, qr{This is yet another test\.});

$body = GET('/test/Testing_2.txt')->content;
like($body, qr{This is another test\.});
