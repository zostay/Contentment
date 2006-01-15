package Contentment::Node::Collection;

use strict;
use warnings;

our $VERSION = '0.03';

use base 'Oryx::Class';

=head1 NAME

Contentment::Node::Collection - Group a set of revisions together

=head1 DESCRIPTION

L<Contentment::Node::Revision> objects may be grouped into a C<Contentment::Node::Collection> to allow for some nifty features. The major feature this adds is the ability to make massive changes to the various parts of a Contentment web site without publishing those changes until you are ready. However, this feature can be used to do a number of different things.

A node collection is a collection of revisions that has a name. Only one revision-per-node may be part of a node collection. Whenever a user visits the web site, exactly one node collection will be assigned to them (the node collection named "HEAD" is the normal default). By default, that user will only see the documents included in that node collection. Thus, it's important that the latest documents be placed into the HEAD node collection (or whatever node collection your typical end-user will see).

A frequent problem in web development happens when you need to make a large change to the site. For example, let's say your company has a site, but is preparing to merge with another company. The other company's standards for site organization have to be adopted by your company, which requires several pages to be moved, split, merged in different ways, etc. 

Rather than duplicating your web configuration on another site, making your changes, and then moving those changes to the main site, Contentment's node collection provides a simpler solution. Your web content team, logs in, clones the HEAD node collection into a new node collection, let's call it "merger-update". Then, they select that node collection instead of HEAD as their default node collection. Now, all modifications they make to the new node collection will exist in that new node collection rather than in the HEAD. Regular site visitors still see the original site, but your content managers see the changes made to "merger-update". By changing the managers' node collection to the "merger-update" set, they can review the site and make their approvals. Finally, once the merger paperwork finishes and the management approves the new site, you simply merge the "merger-update" changes into the HEAD node collection and instantly all your visitors see the new site.

Neat, eh?

=cut

our $schema = {
    attributes => [
        {
            name     => 'group_name',
            type     => 'String',
            required => 1,
        },
        {
            name     => 'created_on',
            type     => 'DateTime',
        },
        {
            name     => 'created_by',
            type     => 'String',
        },
        {
            name     => 'updated_on',
            type     => 'DateTime',
        },
        {
            name     => 'updated_by',
            type     => 'String',
        },
    ],
    associations => [
        {
            role  => 'inherits_from',
            type  => 'Reference',
            class => 'Contentment::Node::Collection',
        },
        {
            role  => 'updated_revisions',
            type  => 'Array',
            class => 'Contentment::Node::Revision',
        },
        {
            role  => 'trashed_nodes',
            type  => 'Array',
            class => 'Contentment::Node',
        },
    ],
};

=head2 METHODS

=over

=item @nodes = $collection-E<gt>revisions

Get the list of all revisions in this collection.

=cut

sub revisions {
    my $self = shift;

    # First, start with any inherited revisions, if we inherit from another
    # collection
    my @revisions;
    if (defined $self->inherits_from) {

        # Create an index of trashed node IDs and nodes that have been updated
        my %trashed_nodes = (
            (map { $_->id      => 1 } $self->trashed_nodes),
            (map { $_->node_id => 1 } $self->updated_revisions),
        );

        # Make sure to exclude any trashed/updated revisions
        @revisions
            = grep { !$trashed_nodes{ $_->node_id } }
              $self->inherits_from->revisions;
    }

    # Add any updates
    push @revisions, $self->updated_revisions;

    return @revisions;
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
