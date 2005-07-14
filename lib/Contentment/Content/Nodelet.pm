package Contentment::Content::Nodelet;

use strict;
use warnings;

use Carp;
use base 'Contentment::SPOPS';

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::Content::Nodelet - Helper class for building node modules

=head1 DESCRIPTION

By using this class, most of the work of making your class into a node module is done for you. This class defines a number of SPOPS rules and other methods that automatically create and update the parent node and revision records associated with this record. This module is also helpful because node objects are a bit atypical in the way operations work:

=over

=item 1.

The primary key/ID-field for nodelet objects is the node_id from the node record.

=item 1.

Node creation involes the creation of two related records other than the main object: the node and the revision.

=item 2.

There are two ways to update a node record:

=over

=item Simple

The simple way to update is simply to change the current record in place, which should result in updates to the revision and node records as well (i.e., new dates and users for certain fields).

=item New Revision

The alternative is to create a new revision of the object. This causes the object to be cloned, the old record to be updated and disabled (thus, modifying certain fields in node and revision for that record), the new record is then created with the alterations and the old object keeps the old values (except for a few dates and users that are updated).

=back

=item 3.

Deletion of a record can also happen in two ways. One is to disable all revisions associated with the record. The other is to actually remove the records from the database altogether. Both are possible.

=item 4.

Searching for records has to be done a bit more carefully to ensure that only the current revision of each record is returned on a normal search. Records that have been "deleted" but are still stored in the database should also be ignored.

=item 4.

However, it wouldn't be of much value if there wasn't some way to search for old revisions and "deleted" records.

=back

See each of the methods below to see details on how the solution to these issues are implemented.

=head2 SPOPS CONFIGURATION

In general, a nodelet is configured in exactly the same way as a regular SPOPS DBI class, but there are a couple additions. Here's the definition of the additional fields and their meaning:

=over

=item id_field

This has no meaning for nodelets. This field is ignored. You will need a primary key (of course) for your table, but you don't need to bother setting it in here. Nodelets are primarily identified by their node_id. This is done through a bit of trickery.

=item rev_id_field (default: "node_rev_id")

You need a field in your table which links your table to the "node_rev_id" field of the node and revision. The name of this field goes in the "ref_id_field" setting (which defaults to "node_rev_id" if not set explicitly). You may link this table to the table named "revision" by this field, if you want the database to enforce the constraint.

=item create_revision (default: 0)

Whenever you save you can pass an optional parameter named "create_revision" to specify whether or not this save should create a new revision. If true, then the object is cloned and the new revision is modified and dates are set on both the new and old object. The current object becomes the new object.

This option sets the default behavior. If you normally want revisions, you can set this to a true value. The default is to not create revisions every time as this is a more expensive operation.

=item disable (default: 0)

Whenever you delete a record, you can pass an optional parameter named "disable" to specify whether or not this delete should just set the disabled flag for the revision. If true, then the object is disabled and not actually removed from the table, but won't be returned on typical queries. Otherwise, the object is completely removed from the database.

This option sets the default behavior. If you normally want to disable rather than to delete records, you can set this to a true value. The default is not to disable records.

=back

=head2 SPOPS API

=over

=item $nodelet = Nodelet-E<gt>fetch($id, \%params)

Fetches the record associated with the given C<$id>. By default, this will return the latest revision for the requested nodelet. If a record has been disabled, then this method will normally return C<undef>. These latter behaviors can be modified with special parameters in C<%params>:

=over

=item include_disabled

If this is set to a true value, then a disabled record can be returned. Without this option, C<undef> would be returned if the current record associated with a nodelet is disabled.

=item revision_id

If this parameter is set, then the "include_disabled" option is implied. This allows you to retrieve a different revision for the nodelet than the head revision.

=back

=cut

=item $nodelets = Nodelet-E<gt>fetch_group(\%params)

This method returns all of the nodelet records for enabled head revisions. That is, only currently enabled records are returned and only the head revision of the nodelet is returned (under normal circumstances).

The behavior of this method can be altered by through the use of parameters in C<%params>:

=over

=item all_revisions

This option implies "include_disabled". This causes every revision matching the given criteria to be returned in the query, so multiple records with the same node_id can be returned (use revision_id to differentiate them).

=item include_disabled

This option (when "all_revisions" isn't present) causes the head revisions from both enabled and disabled records to be returned. Thus, one of each node will be returned, but the node_id for each record will still be unique within the returned set (unless "all_revisions" is set).

=back

=cut

=item $iter = Nodelet-E<gt>fetch_iterator(\%params)

This method is identical to C<fetch_group>, except that an iterator is returned rather than an array reference.

=cut

=item $num = Nodelet-E<gt>fetch_count(\%params)

This method is identical to C<fetch_group>, except that it returns the number of records that would be returned rather than any actual records.

=cut

=item $nodelet-E<gt>save(\%params)

This method saves changes to the record. On create, this method is pretty much identical to the L<SPOPS::DBI> implementation. On update, this method may create a revision, if this has been set as the default behavior or if the "create_revision" option is set to true in C<%params>.

If this method creates a revision, the following steps are taken:

=over

=item 1.

Begin a transaction.

=item 2.

The nodelet record is cloned and a new revision record is created. Modifications are set on the clone and these two records are saved.

=item 3.

The original revision record is disabled and saved.

=item 4.

The node record is touched.

=item 5.

This object becomes a pointer to the new revision.

=item 6.

The transaction is committed.

=back

=cut

=item $nodelet-E<gt>field_update($fields, \%params)

This has essentially the same effect as the L<SPOPS::DBI> object, but uses the "create_revision" parameter (or default value set at configuration time) to possibly create a new revision in the way that C<save> does.

=item Nodelet-E<gt>field_update($fields, \%params)

Again, this is the same as L<SPOPS::DBI>, but takes the additional "create_parameter" or uses the default configuration value to possibly create a new revision I<for each change> in the way that C<save> does. I imagine that creating revisions for bunches of records is an extremely expensive process.

=cut

=item $nodelet-E<gt>remove(\%params)

This method will delete or disable a nodelet record. The operation performed depends upon the "disable" parameter passed to C<%params> (or the default given in the configuration). 

Some of the behavior of this method varies depending on the state of the database. If "disable" is false and this nodelet record represents the only revision in the database for this node_id, then the nodelet, revision, and node records are all deleted. 

If "disable" is false and there are multiple revisions for this node_id besides this one, only this nodelet and associated revision are deleted (see "cascade_delete" for a slightly different behavior). If this nodelet also happens to be the head revision, then the nodelet with the highest revision_id is then selected to replace this one as head (i.e., the record is now effectively disabled, with this particular nodelet revision completely purged from the table). If this behavior doesn't suit your needs (i.e., a different revision should become the head), then you should change the head before deleting the revision.

The behavior of the behavior of this method is further determined by other parameters:

=over

=item cascade_delete

This option has no meaning when the "disable" option is true.

Normally, the remove action will only affect the current revision. Thus, if there exists another revision in the database, the node won't be deleted, just this particular record. 

However, if this option is set, then every revision and nodelet record for this node_id will be purged from the table as well as the node record.

=item disable

If true, no record is purged from any table. Rather, the "enabled" flag on the revision record is set to a false value and saved.

=back

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
