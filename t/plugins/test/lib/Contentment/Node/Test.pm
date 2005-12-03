package Contentment::Node::Test;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Contentment::Node::Revision';

=head1 NAME

Contentment::Node::Test - This node type is used for unit testing

=head1 DESCRIPTION

DESCRIPTION

This is a simple node type used for testing purposes.

=cut

our $schema = {
    attributes => [ {
        name => 'title',
        type => 'String',
    }, {
        name => 'content',
        type => 'Text',
    }, ],
};

sub install {
    __PACKAGE__->storage->deployClass(__PACKAGE__);
}

sub vfs {
    my $path = shift;

    my $title;

    if ($path eq '/') {
        my @titles = map { $_->title } Contentment::Node::Test->search;
        s/\W/_/g foreach @titles;

        return {
            type     => 'd',
            children => \@titles,
        };
    }

    elsif (($title) = $path =~ m{^/(\w+)$}) {
        $title =~ s/_/\\W/g;
        my ($node) 
            = grep { $_->title =~ /$title/ } Contentment::Node::Test->search;
        return undef unless $node;
        return {
            type      => 'f',
            generator => Contentment::Generator->generator('Plain', {
                source     => $node->content,
                properties => {
                    kind  => 'text/plain',
                    title => $node->title,
                },
            }),
        };
    }
                
    else {
        return undef;
    }
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp E<lt>hanenkamp@cpan.orgE<gt>.  All 
Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut

1
