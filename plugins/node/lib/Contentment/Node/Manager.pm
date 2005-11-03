package Contentment::Node::Manager;

use strict;
use warnings;

our $VERSION = '0.02';

use base 'Class::Singleton';

=head1 NAME

Contentment::Node::Manager - Revision set manager and utility

=head1 DESCRIPTION

This class holds the singleton object responsible for determining what revision set is in use by the current request.

As of this writing, the implementation is simplistic and always defines the revision set created during install as the current one.

=head2 METHODS

This class supports the following methods

=over

=item $revision_set = Contentment::Node::Manager-E<gt>get_current_revision_set

Fetch the revision set in use for thise request. In general, you probably don't want to mess with this object too much directly. The internals are kind of icky, which is why the L<Contentment::Node::Manager> class exists after all.

=cut

sub get_current_revision_set {
    return Contentment::Node::RevisionSet->retrieve(1);
}

=item Contentment::Node::Manager-E<gt>add_revision_to_current_revision_set($revision)

This method attaches the given revision to the revision set. Any other revisions from the same node will be removed from the revision set.

=cut

# TODO This code is NASTY. Something needs to be done to make it nicer and most
# especially faster. This is surely extremely dog slow. I think we might want to
# convert the associations in RevisionSet from Arrays to Hashes and use the
# node's ID as a hash key for fast lookups.

sub add_revision_to_current_revision_set {
    my $class    = shift;
    my $revision = shift;

    my $revision_set = $class->get_current_revision_set;

    # Rip out any revision for the same node
    @{ $revision_set->updated_revisions }
        = grep { $_->node->id != $revision->node->id }
               @{ $revision_set->updated_revisions };
    @{ $revision_set->trashed_nodes }
        = grep { $_->id != $revision->node->id }
               @{ $revision_set->trashed_nodes };

    # Add the revision to the update
    push @{ $revision_set->updated_revisions }, $revision;

    # Make sure we're up-to-date
    $revision_set->update;
    $revision_set->commit;
}

=item Contentment::Node::Manager->remove_revision_from_current_revision_set($revision)

Removes this revision from the revision set. This will make the revision (and entire node) appear to be deleted (as far as most of Contentment is concerned) without actually removing the record from the database.

=cut

sub remove_revision_from_current_revision_set {
    my $class    = shift;
    my $revision = shift;

    my $revision_set = $class->get_current_revision_set;

    # Rip it out of the update nodes
    @{ $revision_set->updated_revisions }
        = grep { $_->node->id != $revision->node->id }
               @{ $revision_set->updated_revisions };

    # Unless it's already there, add the node to the trashed list
    push @{ $revision_set->trashed_nodes }, $revision->node
        unless grep { $_->id == $revision->node->id }
                    @{ $revision_set->trashed_nodes };

    # Make sure we're up-to-date
    $revision_set->update;
    $revision_set->commit;
}

=back

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
