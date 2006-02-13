package Contentment::Node::Revision;

use strict;
use warnings;

our $VERSION = '0.06';

use base 'Oryx::Class';

use Class::Date qw( now );

=head1 NAME

Contentment::Node::Revision - Nodes with revisions

=head1 DESCRIPTION

This is the class to subclass if you want to create a node object. Once your class subclasses this object, extends the L<Oryx> schema as desired, and creates any other methods it needs, it will be a full node object. This is really as simple as this:

  package Foo;
  
  use strict;
  use warnings;

  use base qw( Contentment::Node::Revision );

  our $schema = {
      attributes => [{
          name => 'my_field',
          type => 'String',
      }],
  };

  1

And you are done. You'll probably want to add additional methods to make your node more functional if you want to be reachable by the resolver hook handler defined in L<Contentment::Node>. However, that only requires two more method definitions. See L<Contentment::Node/"NODE RESOLVER"> for further details.

=head2 NODE ATTRIBUTES

In addition to the node attributes supported by L<Contentment::Node>, C<Contentment::Node::Revision> objects also support these fields:

=over

=item updated_on

The date the revision was created or last updated.

=item updated_by

The username of the user that created or last updated the revision.

=item comment

A comment describing the revision.

=back

=cut


use Class::Delegator
    send => 'node_id',
    to   => 'node',
    as   => 'id',

    send => 'owner',
    to   => 'node',

    send => 'created_on',
    to   => 'node',

    send => 'created_by',
    to   => 'node',
    
    send => 'revisions',
    to   => 'node';

our $schema = {
    attributes => [
        {
            name => 'updated_on',
            type => 'DateTime',
        },
        {
            name => 'updated_by',
            type => 'String',
        },
        {
            name => 'comment',
            type => 'String',
        },
    ],
    associations => [
        {
            role  => 'node',
            type  => 'Reference',
            class => 'Contentment::Node',
        },
    ],
};

=head2 SPECIAL METHODS

The following methods are defined for node revision objects:

=over

=item $revision = RevisionClass->create(\%args)

This is slightly different from the typical L<Oryx::Class> C<create()> method.  This method actually creates two objects rather than just one and also does some additional setup.

This creates a new node and a new revision under that node according the given C<%args>.

=cut

# The $revise parameter is super-secret and is used by revise() to make sure we
# don't create a node when revising.
sub create {
    my $class  = shift;
    my $proto  = shift;

    # Create the object
    my $self = $class->SUPER::create($proto);

    # If we're creating a Contentment::Node::Revision (i.e., this is being
    # called by Oryx::DB[IM]::Parent), create the node.
    if ($class eq __PACKAGE__ && !$proto->{__node}) {

        # Create the node and set it for the revision and add the revision to
        # the node
        my $node = Contentment::Node->create;
        $self->node($node);
        push @{ $node->revisions }, $self;
        $self->node->update;

        # Confirm changes and set the updated_{on,by} fields
        $self->update;

        # Add the revision to the current collection
        Contentment::Node::Manager->add_revision_to_current_collection($self);
    }

    return $self;
}

sub update {
    my $self = shift;

    $self->updated_on(now);
    $self->updated_by(Contentment->context->security->get_principal->username);

    return $self->SUPER::update;
}

=item $cloned_revision = $revision-E<gt>clone(\%args)

This method operates in pretty much the exact same way as the C<create()> method, except that it duplicates the fields in the original when not modified in the passed C<%args>. This will attach the new revision to the same node as the original.

The clone will become the current revision for the current node collection.

=cut

sub _all_attributes {
    my $self  = shift;
    my $class = ref $self;

    # Start with this object's attributes
    my $attributes = $self->attributes;

    # Look through the parent attributes and add them
    no strict 'refs';
    foreach (@{$class.'::ISA'}) {
        # XXX Does this need to be smarter if they inherit from a non-Oryx
        # class that also provides an attributes method?
        if (UNIVERSAL::can($_, 'attributes')) {
            my $parent_attributes = $_->attributes;
            $attributes = {
                %$parent_attributes,
                %$attributes,
            };
        }
    }

    return $attributes;
}

sub revise {
    my $self              = shift;
    my $create_parameters = shift || {};

    # Copy all the attributes from this object to a new one
    for my $attribute_name (keys %{ $self->_all_attributes }) {
        $create_parameters->{$attribute_name} = $self->$attribute_name
            unless exists $create_parameters->{$attribute_name};
    }

    # Create the clone. Update the parent node.
    $create_parameters->{__create_revision} = 1;
    my $clone = (ref $self)->create($create_parameters);

    # Set the clone's node to the original's node
    my $node = $self->PARENT('Contentment::Node::Revision')->node;
    $clone->PARENT('Contentment::Node::Revision')->node($node);
    $clone->PARENT('Contentment::Node::Revision')->update;

    # Add the clone to the node's list of revision
    push @{ $node->revisions }, $clone;
    $node->update;

    # Make this revision the current one
    Contentment::Node::Manager->add_revision_to_current_collection($clone);

    return $clone;
}

=item $revision-E<gt>trash

This is very similar to C<delete()> except that nothing is removed from the database. Okay... so it's nothing like C<delete()>. It removes the object from the current node collection.

=cut

sub trash {
    my $self = shift;
    Contentment::Node::Manager
        ->remove_revision_from_current_collection($self);
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
