package Contentment::Template::Plugin::Setting;

use strict;
use warnings;

use Contentment::Setting;
use base qw/ Template::Plugin /;

our $VERSION = '0.11';

sub new { bless {}, $_[0]; }
sub settings { Contentment->settings; }

1
