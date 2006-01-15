package Contentment::Template::Plugin::Form;

use strict;
use warnings;

use Contentment::Form;
use base qw/ Template::Plugin /;

our $VERSION = '0.06';

sub new { Contentment::Form->form; }
