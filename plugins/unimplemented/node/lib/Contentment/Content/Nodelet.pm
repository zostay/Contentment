package Contentment::Content::Nodelet;

use strict;
use warnings;

our $VERSION ='0.02';

use Carp;
use Contentment::Content::Node;
use Log::Log4perl;
use SPOPS::ClassFactory qw/ DONE /;
use SPOPS::Initialize;
use SPOPS::Secure qw/ :level :scope /;

use base 'Contentment::SPOPS';

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::Content::Nodelet - Helper class for building node modules

=head1 DESCRIPTION

By using this class, most of the work of making your class into a node module is done for you. This class defines a number of SPOPS rules and other methods that automatically create and update the parent node and revision records associated with this record. This module is also helpful because node objects are a bit atypical in the way operations work:

=over

=item 1.

The primary key/ID-field for nodelet objects is the node_id from the node record.

=item 2.

Node creation involes the creation of two related records other than the main object: the node and the revision.

=item 3.

There are two ways to update a node record:

=over

=item Simple

The simple way to update is simply to change the current record in place, which should result in updates to the revision and node records as well (i.e., new dates and users for certain fields).

=item New Revision

The alternative is to create a new revision of the object. This causes the object to be cloned, the old record to be updated and disabled (thus, modifying certain fields in node and revision for that record), the new record is then created with the alterations and the old object keeps the old values (except for a few dates and users that are updated).

=back

=item 4.

Deletion of a record can also happen in two ways. One is to disable all revisions associated with the record. The other is to actually remove the records from the database altogether. Both are possible.

=item 5.

Searching for records has to be done a bit more carefully to ensure that only the current revision of each record is returned on a normal search. Records that have been "deleted" but are still stored in the database should also be ignored.

=item 6.

However, it wouldn't be of much value if there wasn't some way to search for old revisions and "deleted" records.

=back

See each of the methods below to see details on how the solution to these issues are implemented.

=head2 SPOPS CONFIGURATION

In general, a nodelet is configured in exactly the same way as a regular SPOPS DBI class, but there are a couple additions. Here's the definition of the additional fields and their meaning:

=over

=item id_field

The nodelet must define a field that can link back to the numeric ID of the revision table. This is the "revision_id" field of the revision table. And just to keep you on your toes, this is not the value returned by the C<id()> method. Rather, the "node_id" is returned as the ID value. To get this value, you can use C<$nodelet->revision->id> or as a short-hand C<$nodelet->revision_id>.

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

=item version_number

If this parameter is set, then the "include_disabled" option is implied. This allows you to retrieve a different revision for the nodelet than the head revision.

=back

=cut

sub revision_id {
	my $self = shift;
	my $id_field = $self->id_field;
	return $self->{$id_field};
}

sub revision {
	my $self = shift;
	my $id_field = $self->id_field;
	return Contentment::Content::Revision->fetch(
		$self->{$id_field}, { skip_security => 1 }
	);
}

sub node {
	my $self = shift;
	my $id_field = $self->id_field;
	return Contentment::Content::Node->fetch_by_revision_id(
		$self->{$id_field}, { skip_security => 1 }
	);
}


sub version_number {
	my $self = shift;
	my $rev = $self->revision;
	return $rev->version_number;
}

sub id_clause {
	my $self = shift;
	my $id   = shift;
	my $opt  = shift;
	my $p    = shift;

	my $id_field = $self->id_field;

	my $clause;
	if (ref $self) {
		# Fetch this record from the database. We'll use revision_id instead
		# since it works with SELECT, UPDATE, and DELETE. Doesn't matter if
		# 'noqualify' is set or not. We don't need to qualify anyway. Duh.
		if (!defined $id || $id == $self->id) {
			$clause = "$id_field = ".$self->id;

		# Fetch this record from the database, but the current ID has been
		# changed. This is bad news. First, I don't know a good way to hack this
		# in. Second, changing node IDs is just a plain no-no. "You are the
		# weakest link. Good-bye." We just don't do it.
		} else {
			croak "Cannot generate an ID clause to change IDs. Please, don't change node IDs.";
		}

	# We're performing an initial fetch. We need to gather up our various selves
	# across different tables and figure out who we are. Fetches of this sort
	# **MUST** include node and revision tables in the list.
	} else {
		my $table_name = $self->table_name;

		# select ID and link revisions to nodelets
		$clause = "node.node_id = $id".
			 " AND revision.revision_id = $table_name.$id_field";

		# either link nodes to revisions and select by version_number
		# or select only head revisions
		if ($p->{version_number}) {
			$clause .= " AND revision.node_id = node.node_id".
					   " AND revision.version_number = $p->{version_number}";
		} else {
			$clause .= " AND revision.revision_id = node.head_revision_id";
		}

		unless ($p->{include_disabled}) {
			$clause .= " AND node.enabled = 1";
		}
	}

	return $clause;
}

# This is, as my sister would say, Fan Freaking Tastic. There should be hooks
# from SPOPS to do this, but I'll just replace it until then.
sub fetch {
    my ( $class, $id, $p ) = @_;
    $p ||= {};

    $log->is_debug &&
        $log->debug( "Trying to fetch an item of $class with ID $id and params ",
                     join( " // ", map { sprintf( "%s -> %s", $_, defined $p->{$_} ? $p->{$_} : '' )  }
                                        grep { defined $_ } keys %{ $p } ) );

    # No ID, no object

    return undef  unless ( defined( $id ) and $id ne '' and $id !~ /^tmp/ );

    # Security violations bubble up to caller

    my $level = $p->{security_level};
    unless ( $p->{skip_security} ) {
        $level ||= $class->check_action_security({ id       => $id,
                                                   required => SEC_LEVEL_READ });
    }

    # Do any actions the class wants before fetching -- note that if
    # any of the actions returns undef (false), we bail.

    return undef unless ( $class->pre_fetch_action( { %{ $p }, id => $id } ) );

    my $obj = undef;

    # If we were passed the data for an object, go ahead and create
    # it; if not, check to see if we can whip up a cached object

    if ( ref $p->{data} eq 'HASH' ) {
        $obj = $class->new({ %{ $p->{data} }, skip_default_values => 1 });
    }
    else {
        $obj = $class->get_cached_object({ %{ $p }, id => $id });
        $p->{skip_cache}++;         # Set so we don't re-cache it later
    }

    unless ( ref $obj eq $class ) {
        my ( $raw_fields, $select_fields ) = $class->_fetch_select_fields( $p );
        $log->is_info &&
            $log->info( "SELECTing: ", join( "//", @{ $select_fields } ) );

        # Put all the arguments into a hash (so we can reuse them simply
        # later) and grab the record

        my %args = (
            from   => [ "node", "revision", $class->table_name ],
            select => $select_fields,
            where  => $class->id_clause( $id, undef, $p ),
            db     => $p->{db},
            return => 'single',
        );
        my $row = eval { $class->db_select( \%args ) };
        if ( $@ ) {
            $class->fail_fetch( \%args );
            die $@;
        }

        # If the row isn't found, return nothing; just as if an incorrect
        # (or nonexistent) ID were passed in

        return undef unless ( $row );

        # Note that we pass $p along to the ->new() method, in case
        # other information was passed in needed by it -- however, we
        # need to be careful that certain parameters used by this
        # method (e.g., the optional 'field_alter') is not the same as
        # a parameter of an object -- THAT would be fun to debug...

		# Note that I DO NOT pass id => ... here because that will cause a bad
		# call to id(), which isn't stored in the record anyway. :-P
        $obj = $class->new({ skip_default_values => 1, %{ $p } });
        $obj->_fetch_assign_row( $raw_fields, $row, $p );
    }
    return $obj->_fetch_post_process( $p, $level );
}

sub _execute_multiple_record_query {
	my $class = shift;
	my $p     = shift;

	my $table_name = $class->table_name;
	my $id_field   = $class->id_field;

	$p->{from} ||= [ $table_name, 'node', 'revision' ];
	push @{ $p->{from} }, 'node' unless grep /^node$/, $p->{from};
	push @{ $p->{from} }, 'revision' unless grep /^revision$/, $p->{from};

	my $where;
	if ($p->{all_revisions}) {
		$where = "node.node_id = revision.node_id";
	} else {
		$where = "node.head_revision_id = revision.revision_id";
	}

	$where .= " AND revision.revision_id = $table_name.$id_field";

	unless ($p->{include_disabled}) {
		$where .= " AND node.enabled <> 0"
	}

	$p->{where} = $p->{where} ? "($where) AND ($p->{where})" : $where;

	return $class->SUPER::_execute_multiple_record_query($p);
}

sub save {
	my $self = shift;
	my $p    = shift;

	# Check to see if this is an insert
	my $is_add = $p->{is_add} || !$self->saved;

	# Check to see if we want to create a new revision
	my $create_revision = defined($p->{create_revision}) ? $p->{create_revision} : ($self->{config}{create_revision} || 0);

	# Make sure we're allowed to do this
    unless ( $p->{skip_security} ) {
        $self->check_action_security({ required => SEC_LEVEL_WRITE,
                                       is_add   => $is_add });
    }

	# Start our transaction unless they warn us of nesting
	my $dbh = $self->global_datasource_handle;
	$dbh->begin_work unless $p->{no_transaction};

	# Get the name of the id_field
	my $id_field = $self->id_field;

	eval {
		my ($node, $rev);
		if ($is_add) {
			# Create a new revision
			$rev = Contentment::Content::Revision->new;
			$rev->{version_number} = 1;
			$rev->save({ skip_security => 1 });

			# The real ID should be the revision ID
			$self->{$id_field} = $rev->id;

			# Create a new node with this revision at the head
			$node = Contentment::Content::Node->new;
			$node->{head_revision_id} = $rev->id;
			$node->{module}           = ref($self);
			$node->{enabled}          = $p->{enabled} || 1;
			$node->save({ skip_security => 1 });

			# Set the revision's node and re-save
			$rev->{node_id} = $node->id;
			$rev->save({ skip_security => 1 });
	
			# Insert, don't check seucrity again
			$p->{skip_security} = 1;
			$self->SUPER::save($p);
		} else {
			if ($create_revision) {
				# Get the current node and revision
				$node = $self->node;
				$rev  = $self->revision;

				# Create a new revision
				my $new_rev = Contentment::Content::Revision->new;
				$new_rev->{node_id}        = $node->id;
				$new_rev->{version_number} = $rev->version_number + 1;
				$new_rev->save({ skip_security => 1 });

				# Change the head to the new me
				$node->{head_revision_id} = $new_rev->id;
				$node->save({ skip_security => 1 });

				# Touch the old revision to set the dtime/deleter
				$rev->touch({ skip_security => 1 });
		
				# Update my ID
				$self->{$id_field} = $new_rev->id;

				# Third, SUPER::save to get the other fields
				$p->{skip_security} = 1;
				$p->{is_add} = 1;
				$self->SUPER::save($p);
			} else {
				# Just touch the revision and node to set the dates
				$rev = $self->revision;
				$rev->touch({ skip_security => 1 });
			}
		}
	};

	# On error, rollback and croak. On success, commit and return result.
	if ($@) {
		my $ERROR = $@;
		eval { $dbh->rollback unless $p->{no_transaction}; };
		croak "Nodelet creation failed and rolled back: $ERROR",
			($@ ? " ($@)" : '');
	} else {
		$dbh->commit unless $p->{no_transaction};
		return 1;
	}
}

sub touch {
	my $self = shift;
	$self->save;
}

sub behavior_factory {
	my $class = shift;

	return { id_method => \&_nodelet_conf_id_method };
}

sub _nodelet_conf_id_method {
	my $class = shift;
	my $CONFIG = $class->CONFIG;
	my $id_field = $CONFIG->{id_field};

	eval qq(
		sub $class\::id {
			my \$self = shift;
			my \$node = Contentment::Content::Node->fetch_by_revision_id(\$self->{$id_field}, { skip_security => 1 });
			confess "id() method called while $class (\$self->{$id_field}) in weird state" unless \$node;
			return \$node->id(\@_);
		}
	);

	return ( DONE, undef );
}

=item $nodelets = Nodelet-E<gt>fetch_group(\%params)

This method returns all of the nodelet records for enabled head revisions. That is, only currently enabled records are returned and only the head revision of the nodelet is returned (under normal circumstances).

The behavior of this method can be altered by through the use of parameters in C<%params>:

=over

=item all_revisions

This option implies "include_disabled". This causes every revision matching the given criteria to be returned in the query, so multiple records with the same node_id can be returned (use version_number to differentiate them).

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

If "disable" is false and there are multiple revisions for this node_id besides this one, only this nodelet and associated revision are deleted (see "cascade_delete" for a slightly different behavior). If this nodelet also happens to be the head revision, then the nodelet with the highest version_number is then selected to replace this one as head (i.e., the record is now effectively disabled, with this particular nodelet revision completely purged from the table). If this behavior doesn't suit your needs (i.e., a different revision should become the head), then you should change the head before deleting the revision.

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
