#!/usr/bin/perl

use strict;
use warnings;

use Contentment;

Contentment->begin;
Contentment->handle_cgi;
Contentment->end;

exit(0);
