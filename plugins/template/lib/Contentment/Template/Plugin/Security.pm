package Contentment::Template::Plugin::Security;

use strict;
use warnings;

our $VERSION = '0.04';

use base qw/ Contentment::Security Template::Plugin /;

sub new { Contentment::Security->instance; }

1
