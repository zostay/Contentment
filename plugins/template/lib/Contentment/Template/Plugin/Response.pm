package Contentment::Template::Plugin::Response;

use strict;
use warnings;

our $VERSION = '0.11';

use base qw/ Contentment::Response Template::Plugin /;

sub new { Contentment->context->response }

1
