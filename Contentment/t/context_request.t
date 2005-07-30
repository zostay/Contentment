# vim: set ft=perl :

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use Test::More;

SKIP: {
	eval "
		use Apache::Test ':withtestmore';
		use Apache::TestRequest;
	";
	skip "Apache::Test is not installed.", 15 if $@;

	my $body = GET_BODY("/context_request.txt");

	print $body;

	diag($body) if $body =~ /^not ok/m;
}
