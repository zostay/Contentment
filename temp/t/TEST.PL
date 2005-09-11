#!/usr/bin/perl

use strict;
use warnings;

use Apache::TestRunPerl ();

Apache::TestRunPerl->new->run(@ARGV);
