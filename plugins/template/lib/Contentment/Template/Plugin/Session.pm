package Contentment::Template::Plugin::Session;

use strict;
use warnings;

our $VERSION = '0.01';

use base qw/ Contentment::Session Template::Plugin /;

sub new { bless {}, $_[0] }

1
