package Contentment::Template::Plugin::Response;

use strict;
use warnings;

our $VERSION = '0.03';

use base qw/ Contentment::Response Template::Plugin /;

sub new { Contentment::Response->instance }

1
