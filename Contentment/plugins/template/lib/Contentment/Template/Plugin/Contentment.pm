package Contentment::Template::Plugin::Contentment;

use strict;
use warnings;

use Contentment;
use base 'Template::Plugin';

our $VERSION = '0.04';

sub new { bless {}, $_[0]; }
sub global_configuration { return Contentment->global_configuration; }

1
