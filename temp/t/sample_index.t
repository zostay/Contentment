# vim: set ft=perl :

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use Test::More tests => 1;

my $conf = Contentment->configuration;

SKIP: {
	eval " 
		use Apache::Test ':withtestmore';
		use Apache::TestRequest;
	";
	skip "Apache::Test is not installed.", 1 if $@;

	my $data = GET_BODY('/index.html');
	like ($data, qr{<title>\s*Welcome to Contentment\s*-\s*$conf->{site_title}\s*</title>}, 'Correct sample title.');
}
