# vim: set ft=perl:

use strict;

use lib 't/lib';

use Contentment;
use Contentment::Test;
use Test::More tests => 1;

Contentment->run_plugin("Foo::Bar::baz", 1);
