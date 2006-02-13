package Contentment::Template::Plugin::Site;

use strict;
use warnings;

our $VERSION = '0.11';

use base qw/ Template::Plugin /;

sub new { return Contentment->context->current_site; }

1
