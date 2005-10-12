package Contentment::Oryx;

use strict;
use warnings;

our $VERSION = '0.01';

use Contentment;
use Oryx;

use base 'Oryx::Schema';

my $init = Contentment->global_configuration;
our $storage = Oryx->connect($init->{oryx_connection}, 'Contentment::Oryx');

1
