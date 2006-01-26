package Contentment::Test::Indexer;

use strict;
use warnings;

our $VERSION = '0.02';

sub indexes { return (Contentment::Test::Index->instance) }

sub register_indexer {
    Contentment::Index->register_index(bless {}, 'Contentment::Test::Indexer');
}

1
