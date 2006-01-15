package Contentment::Template::Plugin::Request;

use strict;
use warnings;

our $VERSION = '0.03';

use base qw/ Contentment::Request Template::Plugin /;

sub new { Contentment::Request->instance }

1
