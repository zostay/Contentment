package Contentment::Template::Plugin::Request;

use strict;
use warnings;

our $VERSION = '0.11';

use base qw/ Contentment::Request Template::Plugin /;

sub new { Contentment->context->request }

1
