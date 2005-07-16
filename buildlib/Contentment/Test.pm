package Contentment::Test;

use strict;

our $VERSION = '0.02';

no warnings 'redefine';

sub Contentment::Config::ETC_DIR() {
	return "t/etc";
}

1
