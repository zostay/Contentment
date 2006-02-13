package Contentment::Test::Indexer;

use strict;
use warnings;

our $VERSION = '0.02';

sub indexes { return (Contentment::Test::Index->instance) }

sub register_indexer {
    my $context = shift;
    $context->catalog->register_indexer(bless {}, 'Contentment::Test::Indexer');
}

1
