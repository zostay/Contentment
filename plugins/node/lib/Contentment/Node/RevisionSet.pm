package Contentment::Node::RevisionSet;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Oryx::Class';

=head1 NAME

Contentment::Node::RevisionSet - Group a set of revisions together

=head1 DESCRIPTION

L<Contentment::Node::Revision> objects may be grouped into a C<Contentment::Node::RevisionSet> to allow for some nifty features. The major feature this adds is the ability to make massive changes to the various parts of a Contentment web site without publishing those changes until you are ready. However, this feature can be used to do a number of different things.

A revision-set is a collection of revisions that has a name. Only one revision-per-node may be part of a revision-set. Whenever a user visits the web site, exactly one revision-set will be assigned to them (the revision-set named "HEAD" is the normal default). By default, that user will only see the documents included in that revision-set. Thus, it's important that the latest documents be placed into the HEAD revision-set (or whatever revision set your typical end-user will see).

A frequent problem in web development happens when you need to make a large change to the site. For example, let's say your company has a site, but is preparing to merge with another company. The other company's standards for site organization have to be adopted by your company, which requires several pages to be moved, split, merged in different ways, etc. 

Rather than duplicating your web configuration on another site, making your changes, and then moving those changes to the main site, Contentment's revision-sets provides a simpler solution. Your web content team, logs in, clones the HEAD revision-set into a new revision-set, let's call it "merger-update". Then, they select that revision-set instead of HEAD as their default revision-set. Now, all modifications they make to the new revision-set will exist in that new revision-set rather than in the HEAD. Regular site visitors still see the original site, but your content managers see the changes made to "merger-update". By changing the managers' revision-set to the "merger-update" set, they can review the site and make their approvals. Finally, once the merger paperwork finishes and the management approves the new site, you simply merge the "merger-update" changes into the HEAD revision-set and instantly all your visitors see the new site.

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
            class => 'Contentment::Node::RevisionSet',
        },
        {
            role  => 'updated_revisions',
            type  => 'Array',
            class => 'Contentment::Node::Revision',
        },
        {
            role  => 'trashed_revisions',
            type  => 'Array',
            class => 'Contentment::Node::Revision',
        },
    ],
};

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
