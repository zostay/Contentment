package Contentment::Node;

use strict;
use warnings;

our $VERSION = '0.06';

use base 'Oryx::Class';

use List::MoreUtils qw( uniq );

=head1 NAME

Contentment::Node - Node storage for Contentment

=head1 DESCRIPTION

This package is primarily intended for documentation to the end user. Don't use this class directly. Rather use L<Contentment::Node::Revision> and L<Contentment::Node::Collection> instead.

Use the documentation here to get the big picture.

=head2 NODES

In several content management systems, it has become popular to store data into nodes. Each node represents one document (or a document series if the CMS provides revision control). Contentment actually allows for some flexibility by allowing the use of regular file system files along with database nodes, but the real power of Contentment is in the nodes.

To create a new type of Node, you need to subclass either the L<Contentment::Node::Revision> class. Then, create additional schema items using the L<Oryx> persistence system. Then, you need to implement the generator methods for your object. For example, if you chose to extend C<Contentment::Node> to create a book review node type, you could do something like this:

  package MyBookReview;

  use strict;
  use warnings;

  use base qw( Contentment::Node::Revision );

  our $schema = {
      attributes => [{
          name => 'book_title',
          type => 'String',
      },{
          name => 'book_author',
          type => 'String',
      },{
          name => 'book_publisher',
          type => 'String',
      },{
          name => 'book_pubdate',
          type => 'DateTime',
      },{
          name => 'book_isbn',
          type => 'String',
      }],
  };

  sub get_property {
      my $self = shift;
      local $_ = shift;

      /^title$/     && do { return $self->book_title }
      /^author$/    && do { return $self->book_author }
      /^publisher$/ && do { return $self->book_publisher }
      /^pubdate$/   && do { return $self->book_pubdate }
      /^isbn$/      && do { return $self->book_isbn }
  }

  sub generated_kind { return 'text/html' }

  sub generate {
      # print out the HTML...
  }

  1;

And that's pretty much it. This is now a functional node subclass.

Finally, you'll probably want to use your node class by instantiating a few. However, you should be aware of a few details before you continue. Read on.

=head2 NODE REVISIONS

Now, it wouldn't be much of a publishing system without the ability to keep old revisions around. The details of this work are found in L<Contentment::Node::Revision> and L<Contentment::Node::Collection>.

Basically, a node object is really a collection of revisions. In general, each time you make a change to a node, a new revision is created and selected as the current revision. The old revision exists in limbo where you can't see it anymore unless you explicitly ask to see it.

=head2 NODE REVISION-SETS

The real power of the Contentment revision system is with the revision-sets. When I said, "a new revision is created and I<selected as the current revision>," what I really meant was that the new revision replaces the old revision in the current revision-set. When a user visits the web site, she will be assigned a revision-set containing the revisions visible to her. By default, this revision-set is named "HEAD".

When an editor edits a node, the new revision created replaces the old revision in his current revision set. He could also change the revision-set he's using so that his changes aren't a part of the main web site. Thus, a new revision-set could be cloned from the HEAD, modified until all the new pieces are just right, and, then, merged back into the HEAD.

To "delete" a node, you don't have to remove the data from the database, just remove it from the change set.

=head2 NODE ATTRIBUTES

Each node object has the following information associated with it:

=over

=item owner

This is a username identifying the node's owner. This can help you if your node subclass needs to base security decisions on the node owner. The owner may be C<undef> if ownership isn't significant or is unknown.

=item created_on

The date the node was created. This is set automatically.

=item created_by

The username of the current principal when the node was created. This is set automatically.

=back

=cut

our $schema = {
    attributes => [
        {
            name => 'owner',
            type => 'String',
        },
        {
            name => 'created_on',
            type => 'DateTime',
        },
        {
            name => 'created_by',
            type => 'String',
        },
    ],
    associations => [
        {
            role  => 'revisions',
            type  => 'Array',
            class => 'Contentment::Node::Revision',
        },
    ],
};

=head2 HOOK HANDLERS

=over

=item Contentment::Node::install

This handles the "Contentment::install" hook. It deploys the L<Contentment::Node>, L<Contentment::Node::Revision>, and L<Contentment::Node::Collection> schemas.

=cut

sub install {
    my $context = shift;
    my $storage = $context->storage;
    # Create the tables
    $storage->deployClass('Contentment::Node');
    $storage->deployClass('Contentment::Node::Revision');
    $storage->deployClass('Contentment::Node::Collection');

    # Create the primary revision set
    my $HEAD_revision_set = Contentment::Node::Collection->create({
        group_name => 'HEAD',
    });
}

=item Contentment::Node::simple

Implements the "Contentment::VFS::simple" hook and adds a new set of paths under the "/node" directory.

=cut

sub vfs {
    my $path = shift;

    my ($year, $month, $day, $id);

    if ($path eq '') {
        return {
            type     => 'd',
            children => [ 'id', 'created' ],
        };
    }

    elsif ($path eq 'id') {
        return {
            type     => 'd',
            children => [
                map { $_->id } 
                Contentment::Node::Manager->get_current_collection->revisions
            ],
        };
    }

    elsif (($id) = $path =~ m{^id/(\d+)$}) {
        return {
            type      => 'fd',
            generator => Contentment::Node->retrieve($id)->generator,
            children  => [ 'rev', 'col' ],
        };
    }

    elsif ($path eq 'created') {
        return {
            type     => 'd',
            children => [ 'year', 'month', 'day' ],
        };
    }

    elsif ($path =~ m{^created/(?:year|month|day)$}) {
        return {
            type     => 'd',
            children => [
                uniq map { $_->created_on->year }
                Contentment::Node::Manager->get_current_collection->revisions
            ],
        };
    }

    elsif (($year) = $path =~ m{^created/year/(\d+)$}) {
        return {
            type     => 'd',
            children => [
                map { $_->id }
                grep { $_->created_on->year == $year }
                Contentment::Node::Manager->get_current_collection->revisions
            ],
        };
    }

    elsif (($year, $id) = $path =~ m{^created/year/(\d+)/(\d+)$}) {
        my $node = Contentment::Node->retrieve($id);
        if ($node->created_on->year != $year) {
            Contentment::Exception->throw(
                message => "No node with ID $id created in year $year.",
            );
        }

        return {
            type      => 'f',
            generator => $node->generator,
        };
    }

    elsif (($year) = $path =~ m{^created/(?:day|month)/(\d+)$}) {
        return {
            type     => 'd',
            children => [
                uniq map { $_->created_on->month }
                grep { $_->created_on->year == $year }
                Contentment::Node::Manager->get_current_collection->revisions
            ],
        };
    }

    elsif (($year, $month) = $path =~ m{^created/month/(\d+)/(\d+)$}) {
        return {
            type     => 'd',
            children => [
                uniq map { $_->id }
                grep { $_->created_on->year  == $year 
                    && $_->created_on->month == $month }
                Contentment::Node::Manager->get_current_collection->revisions
            ],
        };
    }

    elsif (($year, $month, $id) 
    = $path =~ m{^created/month/(\d+)/(\d+)/(\d+)$}) {
        my $node = Contentment::Node->retrieve($id);
        if ($node->created_on->year  != $year
         || $node->created_on->month != $month) {
            Contentment::Exception->throw(
                message => "No node with ID $id created ".
                           "in year $year and month $month.",
            );
        }

        return {
            type      => 'f',
            generator => $node->generator,
        };
    }

    elsif (($year, $month) = $path =~ m{^created/day/(\d+)/(\d+)$}) {
        return {
            type     => 'd',
            children => [
                uniq map { $_->created_on->day }
                grep { $_->created_on->year  == $year 
                    && $_->created_on->month == $month }
                Contentment::Node::Manager->get_current_collection->revisions
            ],
        };
    }

    elsif (($year, $month, $day) 
    = $path =~ m{^created/day/(\d+)/(\d+)/(\d+)$}) {
        return {
            type     => 'd',
            children => [
                uniq map { $_->id }
                grep { $_->created_on->year  == $year 
                    && $_->created_on->month == $month 
                    && $_->created_on->day   == $day }
                Contentment::Node::Manager->get_current_collection->revisions
            ],
        };
    }

    elsif (($year, $month, $day, $id) 
    = $path =~ m{^created/day/(\d+)/(\d+)/(\d+)/(\d+)$}) {
        my $node = Contentment::Node->retrieve($id);
        if ($node->created_on->year  != $year
         || $node->created_on->month != $month
         || $node->created_on->day   != $day) {
            Contentment::Exception->throw(
                message => "No node with ID $id created ".
                           "in year $year and month $month and day $day.",
            );
        }

        return {
            type      => 'f',
            generator => $node->generator,
        };
    }

    else {
        return undef;
    }
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
