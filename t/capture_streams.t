# vim: set ft=perl:

use strict;

use Contentment;
use Contentment::Test;
use File::Temp 'tempfile';
use Test::More tests => 1;

Contentment->configuration;

my $in = tempfile;
my $out = tempfile;

print $in "foo\n";
print $in "bar\n";
print $in "baz\n";
print $in "quux\n";

seek $in, 0, 0;

Contentment->capture_streams($in, $out, sub {
	while (<STDIN>) {
		print uc($_);
	}
});

seek $out, 0, 0;

is_deeply([ <$out> ], [ "FOO\n", "BAR\n", "BAZ\n", "QUUX\n" ]);
