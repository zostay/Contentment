package Contentment::Template::Plugin::Response;

use strict;
use warnings;

our $VERSION = '0.01';

use base qw/ Contentment::Response Template::Plugin /;

sub new { bless {}, $_[0] }

1
