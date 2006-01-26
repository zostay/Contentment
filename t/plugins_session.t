# vim: set ft=perl :

use strict;
use Test::More tests => 1;

SKIP: {
	eval "use Apache::TestRequest qw/ GET GET_BODY /";
	skip "Apache::Test is not installed.", 1 if $@;

	Apache::TestRequest::user_agent(cookie_jar => {});

    GET('/plugins/session/session1.txt');

	my $body = GET_BODY('/plugins/session/session2.txt');

	like($body, qr/^foo = 1$/);
}
