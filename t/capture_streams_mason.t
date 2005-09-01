# vim: set ft=perl:

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use Test::More skip_all => "Known to fail. Waiting for IO::NestedCapture to be implemented.";

my $conf = Contentment->configuration;

SKIP: {
	eval "
		use Apache::Test ':withtestmore';
		use Apache::TestRequest;
	";
	skip "Apache::Test is not installed.", 1 if $@;

	my $data = GET_BODY("/capture_streams.html");
	like ($data, qr{foo\s+bar\s+baz\s+quux\s+quuux});
}
