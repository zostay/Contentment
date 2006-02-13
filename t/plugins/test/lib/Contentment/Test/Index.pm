package Contentment::Test::Index;

use strict;
use warnings;

our $VERSION = '0.02';

use base qw( Class::Singleton );

use Contentment::Catalog qw( $SEARCH $LIST_TERMS );

sub name { "Contentment::Test::Index" }

sub title { "Test" }

sub description { "An index of file generators with starting vowels in their basename---used just for testing." }

sub features { $SEARCH | $LIST_TERMS }

sub search {
    my $self = shift;

    my @terms;
    for my $string (@_) {
        if ($string =~ /^[AEIOU]$/) {
            push @terms, Contentment::Test::Term->new($string)
        }
    }

    return @terms;
}

sub terms {
    my $self = shift;
    return map { Contentment::Test::Term->new($_) } qw( A E I O U );
}

1
