package Contentment::Template::Plugin::Node;

use strict;
use warnings;

our $VERSION = '0.08';

use base qw/ Template::Plugin /;

sub new {
    my $class     = shift;
    my $context   = shift;
    my $node_type = shift;

    if ($node_type !~ /^[\w:]+$/) {
        Contentment::Exception->throw(
            message => "The node type given is invalid: $node_type",
        );
    }

    return bless {
        node_type => "Contentment::Node::$node_type",
    }, $class;
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    $AUTOLOAD =~ s/^Contentment::Template::Plugin::Node:://;
    return if $AUTOLOAD eq 'DESTROY';

    $self->{node_type}->$AUTOLOAD(@_);
}

1
