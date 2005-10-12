package Contentment::Template::Plugin::Request;

use strict;
use warnings;

our $VERSION = '0.01';

use base qw/ Contentment::Request Template::Plugin /;

sub new { bless {}, $_[0] }

1
