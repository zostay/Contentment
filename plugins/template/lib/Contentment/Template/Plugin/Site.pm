package Contentment::Template::Plugin::Site;

use strict;
use warnings;

our $VERSION = 0.09;

use base qw/ Template::Plugin /;

sub new { return Contentment::Site->current_site; }

1
