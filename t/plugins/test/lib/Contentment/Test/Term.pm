package Contentment::Test::Term;

use strict;
use warnings;

our $VERSION = '0.02';

sub new {
    my $class  = shift;
    my $letter = shift;

    return bless { letter => $letter }, $class;
}

sub name {
    my $self = shift;
    return lc $self->{letter};
}

sub title {
    my $self = shift;
    return uc $self->{letter};
}

sub description {
    my $self = shift;
    my $letter = uc $self->{letter};
    return qq(The vowel "$letter".);
}

sub index { Contentment::Test::Index->instance }

sub generators {
    my $self = shift;

    # We want all files starting with the given vowel.
    my $wanted = sub {
        my $file = shift;
        my $name = $file->basename;
        return scalar($name =~ /^$self->{letter}/i);
    };

    my $vfs = Contentment->context->vfs;
    my @files = $vfs->find($wanted, '/');
    return map { my $g = $_->generator; defined $g ? $g : () } @files;
}

1
