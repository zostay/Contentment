package Contentment::Template::Plugin::Generator;

use strict;
use warnings;

our $VERSION = '0.08';

use base qw/ Contentment::Hooks Template::Plugin /;

sub new { $_[0]->instance }

1
