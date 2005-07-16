# vim: set ft=perl:

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use File::Temp 'tempfile';
use Test::More;

my $tie_class;
eval { 
	require IO::String;
	$tie_class = 'IO::String';
};

eval {
	require IO::Scalar;
	$tie_class = 'IO::Scalar';
} unless (defined $tie_class);

if (defined $tie_class) {
	plan tests => 4;
} else {
	diag("Skipping tie tests because neither IO::String nor IO::Scalar are present.");
	plan tests => 1;
}

Contentment->configuration;

sub capture_test {
	my ($in, $out) = @_;

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
}

capture_test(scalar(tempfile), scalar(tempfile));
if (defined $tie_class) {
	capture_test($tie_class->new, scalar(tempfile));
	capture_test(scalar(tempfile), $tie_class->new);
	capture_test($tie_class->new, $tie_class->new);
}
