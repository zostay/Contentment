package Contentment::Test;

use strict;

our $VERSION = '0.01';

use File::Path;

mkpath 'blib/tmp';

no warnings 'redefine';

sub Contentment::Config::ETC_DIR() {
	return "t/etc";
}

1
