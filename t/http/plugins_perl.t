# vim: set ft=perl :

use strict;
use Contentment::Test;
use Test::More tests => 3;

my $res = GET('/plugins/perl/perl.txt');
my $body = $res->content;

# test that the string start right, since CGI usually adds "; encoding=..."
# on to the end
like($res->header('Content-Type'), qr{^text/plain});
like($body, qr/^Hello World!/m);
like($body, qr{^path = /plugins/perl/perl\.pl}m);
