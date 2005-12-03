package Contentment::Node::Revision;

use strict;
use warnings;

our $VERSION = '0.03';

use base 'Oryx::Class';

=head1 NAME

Contentment::Node::Revision - Nodes with revisions

=head1 DESCRIPTION

This is the class to subclass if you want to create a node object. Once your class subclasses this object, extends the L<Oryx> schema as desired, and creates any other methods it needs, it will be a full node object. This is really as simple as this:

  package Foo;
  
  use strict;
  use warnings;

  use base qw( Contentment::Node::Revision );

  our $schema = {
      associations => [{
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

sub create {
    my $class = shift;

    my $node = Contentment::Node->create;
    my $self = $class->SUPER::create(@_);

    $self->node($node);
    push @{ $node->revisions }, $self;
    $self->node->update;
    $self->update;

    Contentment::Node::Manager->add_revision_to_current_collection($self);

    return $self;
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

sub clone {
    my $self              = shift;
    my $create_parameters = shift || {};

    # Copy all the attributes from this object to a new one
    for my $attribute_name (keys %{ $self->_all_attributes }) {
        $create_parameters->{$attribute_name} = $self->$attribute_name
            unless exists $create_parameters->{$attribute_name};
    }

    # Create the clone. Update the parent node.
    my $clone = (ref $self)->SUPER::create($create_parameters);
    $clone->node($self->node);
    push @{ $clone->node->revisions }, $clone;
    $clone->node->update;
    $clone->update;

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
