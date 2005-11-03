package Contentment::Template::Plugin::Setting;

use strict;
use warnings;

use Contentment::Setting;
use base qw/ Template::Plugin /;

our $VERSION = '0.04';

sub new { bless {}, $_[0]; }
sub settings { Contentment::Setting->instance; }

1
