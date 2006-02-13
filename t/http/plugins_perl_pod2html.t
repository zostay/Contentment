# vim: set ft=perl :

use strict;
use Contentment::Test;
use Test::More tests => 4;

my $body = GET('/plugins/perl/pod.html')->content;

like($body, qr{<h1>NAME</h1>});
like($body, qr{<p>Simple Test Case</p>});
like($body, qr{<h1>DESCRIPTION</h1>});
like($body, qr{<p>This is a test.</p>});
