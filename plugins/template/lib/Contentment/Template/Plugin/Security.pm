package Contentment::Template::Plugin::Security;

use strict;
use warnings;

our $VERSION = '0.11';

use base qw/ Contentment::Security Template::Plugin /;

sub new { Contentment->context->security; }

1
