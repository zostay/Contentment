# vim: set ft=perl :

use strict;
use Test::More tests => 10;

SKIP: {
	eval "use Apache::TestRequest 'GET_BODY'";
	skip "Apache::Test is not installed.", 10 if $@;

	my $body = GET_BODY('/settings.txt');
	my @body = split /[\n\r]+/, $body;

	is(shift(@body), 'testing_foo = foo');
	is(shift(@body), 'testing_bar = 2');
	is(shift(@body), 'testing_baz refs a ARRAY');
	is(shift(@body), 'testing_qux refs a HASH');
	is(shift(@body), 'testing_baz[0] = foo');
	is(shift(@body), 'testing_baz[1] = bar');
	is(shift(@body), 'testing_baz[2] = baz');
	is(shift(@body), 'testing_baz[3] = qux');
	is(shift(@body), 'testing_qux{foo} = 1');
	is(shift(@body), 'testing_qux{bar} = 2');
}
