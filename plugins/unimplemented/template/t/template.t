# vim: set ft=perl :

use strict;
use Test::More tests => 6;

SKIP: {
	eval "use Apache::TestRequest 'GET_BODY'";
	skip "Apache::Test is not installed.", 1 if $@;

	my $body;
   
	# Embperl-ish MicroMason
	$body = GET_BODY('/embperl.html?who=foo');
	like($body, qr{^<p>Hello foo!</p>$}, 'Embperl');

	# HTML::Mason-ish MicroMason
	$body = GET_BODY('/mason.html');
	like($body, qr{^<p>Hello World!</p>$}, 'HTML::Mason no args');

	$body = GET_BODY('/mason.html?who=bar');
	like($body, qr{^<p>Hello bar!</p>$}, 'HTML::Mason args');

	# HTML::Template-ish MicroMason
	$body = GET_BODY('/html-template.html?who=baz');
	like($body, qr{^<p>Hello baz!</p>$}, 'HTML::Template');

	# Server Pages-ish MicroMason
	$body = GET_BODY('/server-pages.html?who=qux');
	like($body, qr{^<p>Hello qux!</p>$}, 'ServerPages');

	# Text::Template-ish MicroMason
	$body = GET_BODY('/text-template.html?who=qux');
	like($body, qr{^<p>Hello quux!</p>$}, 'Text::Template');
}
