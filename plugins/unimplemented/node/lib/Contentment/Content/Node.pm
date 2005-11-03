package Contentment::Content::Node;

use strict;
use warnings;

our $VERSION = '0.04';

use Carp;
use DateTime;
use Log::Log4perl;
use SPOPS::Initialize;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::Content::Node - Handy module for storing common data

=head1 DESCRIPTION

Borrowing from so many other content management systems (esp. Drupal and Everything), the node concept is that most content can be treated similarly. All content records are associated with the node. When creating content in other modules, content modules should create a node object and refer to it for generic content information.

This module isn't a good starting place. The first document you should examine is L<Contentment::Content::Nodelet>, which is the convenience class utilizing the C<Contentment::Content::Node> and C<Contentment::Content::Revision> classes defined here. This module doesn't function on its own, but only in the context of a nodelet object.

=head1 NODE DATA

TODO Add documentation for the Node schema.

=cut

my %spops = (
	node => {
		class			=> 'Contentment::Content::Node',
		isa				=> [ qw/ Contentment::SPOPS / ],
		rules_from		=> [ qw/ SPOPSx::Tool::DateTime Contentment::Security / ],
		base_table		=> 'node',
		field			=> [ qw/
			node_id
			head_revision_id
			module
			enabled
			ctime
			creator
			mtime
			updater
			dtime
			deleter
		/ ],
		id_field		=> 'node_id',
		increment_field	=> 1,
		datetime_format	=> {
			ctime => 'DateTime::Format::MySQL',
			mtime => 'DateTime::Format::MySQL',
			ctime => 'DateTime::Format::MySQL',
		},
		user_fields     => [ qw/ creator updater deleter / ],
		has_a			=> { 'Contentment::Content::Revision' => { head_revision => 'head_revision_id' } },
		links_to		=> { 'Contentment::Content::Revision' => 'revision' },
	},
	revision => {
		class			=> 'Contentment::Content::Revision',
		isa				=> [ qw/ Contentment::SPOPS / ],
		rules_from		=> [ qw/ SPOPSx::Tool::DateTime Contentment::Security / ],
		base_table		=> 'revision',
		field			=> [ qw/
			revision_id
			version_number
			node_id
			ctime
			creator
			mtime
			updater
			dtime
			deleter
		/ ],
		id_field		=> 'revision_id',
		increment_field	=> 1,
		datetime_format	=> {
			ctime => 'DateTime::Format::MySQL',
			mtime => 'DateTime::Format::MySQL',
			ctime => 'DateTime::Format::MySQL',
		},
		user_fields     => [ qw/ creator updater deleter / ],
		has_a			=> { 'Contentment::Content::Node' => 'node_id' },
	},
);

SPOPS::Initialize->process({ config => \%spops });

__PACKAGE__->_create_table('MySQL', 'node', q(
	CREATE TABLE node (
		node_id			INT(11) NOT NULL AUTO_INCREMENT,
		head_revision_id INT(11) NOT NULL,
		module			VARCHAR(100) NOT NULL,
		enabled			INT(1) NOT NULL,
		ctime			DATETIME NOT NULL,
		creator			VARCHAR(150) NOT NULL,
		mtime			DATETIME NOT NULL,
		updater			VARCHAR(150) NOT NULL,
		dtime			DATETIME,
		deleter			VARCHAR(150),
		PRIMARY KEY (node_id),
		UNIQUE (head_revision_id));
));

__PACKAGE__->_create_table('MySQL', 'revision', q(
	CREATE TABLE revision (
		revision_id		INT(11) NOT NULL AUTO_INCREMENT,
		node_id			INT(11),
		version_number	INT(11) NOT NULL,
		ctime			DATETIME NOT NULL,
		creator			VARCHAR(150) NOT NULL,
		mtime			DATETIME NOT NULL,
		updater			VARCHAR(150) NOT NULL,
		dtime			DATETIME,
		deleter			VARCHAR(150),
		PRIMARY KEY (revision_id),
		UNIQUE (node_id, version_number));
));

=head1 NODE/REVISION FEATURES

Each node record inherits from the security of the module record it is associated with. Thus, if a user cannot access the module record, they cannot access any Node information. When creating a Node record, the Node will fail to create if the module field has been set to a module for which the user is not permitted to create, then Node creation will also fail. The same is true for Revisions.

NOTE: It is important that all revisions of a node have the same security. This is because C<Contentment::Content::Node> is only able to use the head revision module object for security checking.

On update, the Node will automatically set the appropriate time and user fields to the current time and the current user (as defined by C<L<DateTime>-E<gt>now> and C<L<Contentment::Context>::current_user>). These are the ctime, creator, mtime, updater, dtime, and deleter fields. The ctime, creator, mtime, and updater fields are set when a node is created. The mtime and updater fields are set whenever the node is updated and enabled is true. The dtime and deleter fields are set whenever the node is updated and enabled is false. The same is true for Revisions.

I would also like to note that a notably absent field are some extra fields like "published" or "sticky" or "promoted" or "moderated," etc. These fields are part of nodes in many frameworks, but not here. Those are workflow related and the node API doesn't enforce any workflow concepts. As of this writing, I haven't yet worked out the details of the workflow system I'd like to add, but I have decided to hold the general idea of nodes separate from the workflow at this time (this, of course, is subject to change).

Also notably absent are titles and other data. I'd like to keep anything beyond the very basics in custom node modules rather than make node a container for data.

=cut

sub get_security {
	my $self = shift;
	my ($p) = @_;

	my $item;
	if (ref($self)) {
		$item = $self;
	} else {
		my $id = ref($self) ? $self->id : $p->{object_id};
		$item = $self->fetch($id, { skip_security => 1 });
	}

	my $module_object = $item->module_object({ skip_security => 1 });
	return $module_object->get_security(@_);
}

sub _node_update {
	my $self = shift;
	my $p    = shift;

	my $now = DateTime->now;

	if ($p->{is_add}) {
		$self->{ctime} = $now;
		$self->{creator} = Contentment->context->current_user;
		$self->{mtime} = $now;
		$self->{updater} = Contentment->context->current_user;
	}
	
	if ($self->{enabled}) {
		$self->{mtime} = $now;
		$self->{updater} = Contentment->context->current_user;
	} else {
		$self->{dtime} = $now;
		$self->{deleter} = Contentment->context->current_user;
	}

	return __PACKAGE__;
}

sub ruleset_factory {
	my ($class, $rs_table) = @_;
	unshift @{ $rs_table->{pre_save_action} }, \&_node_update;
	return __PACKAGE__;
}

sub fetch_by_revision_id {
	my $class = shift;
	my $revision_id = shift;

	my $rev = Contentment::Content::Revision->fetch($revision_id, @_);
	my $node = $class->fetch($rev->node_id, @_);
	return $node;
}

=head1 NODE METHODS

In order to make this API a little more usable, several features have been added to the typical SPOPS features.

=over

=item $obj = $node-E<gt>module_object

This method returns the object represented by the node's module field. This method will call the module's C<fetch()> method to retrieve the object for the head revision.

=cut

sub module_object {
	my $self = shift;
	my $p = shift;

	if (defined $self->head_revision) {
		return $self->{module}->fetch($self->head_revision->id, $p);
	} else {
		return undef;
	}
}

=item $node-E<gt>touch

This method should not be called directly as it is called the C<Contentment::Content::Revision::touch>. This method calls the C<save> method to trigger time and user field updates.

=cut

sub touch {
	my $self = shift;
	my $p    = shift;

	$self->save($p);
}

=back

=cut

package Contentment::Content::Revision;

sub get_security {
	my $self = shift;
	my ($p) = @_;

	my $item;
	if (ref($self)) {
		$item = $self;
	} else {
		my $id = ref($self) ? $self->id : $p->{object_id};
		$item = $self->fetch($id, { skip_security => 1 });
	}

	my $module_object = $item->module_object({ skip_security => 1 });
	use Carp;
	confess "Your code is fucked." unless $module_object;
	return $module_object->get_security(@_);
}

sub _revision_update {
	my $self = shift;
	my $p    = shift;

	my $now = DateTime->now;

	if ($p->{is_add}) {
		$self->{ctime} = $now;
		$self->{creator} = Contentment->context->current_user;
		$self->{mtime} = $now;
		$self->{updater} = Contentment->context->current_user;
	}

	my $node = Contentment::Content::Node->fetch($self->{node_id}, { skip_security => 1 });

	if (!$p->{is_add} && ($p->{disable} || $node->{head_revision_id} != $self->id)) {
		$self->{dtime} = $now;
		$self->{deleter} = Contentment->context->current_user;
	} else {
		$self->{mtime} = $now;
		$self->{updater} = Contentment->context->current_user;
	}

	return __PACKAGE__;
}

sub ruleset_factory {
	my ($class, $rs_table) = @_;
	unshift @{ $rs_table->{pre_save_action} }, \&_revision_update;
	return __PACKAGE__;
}


=head1 REVISION DATA

TODO Add documentation for the Revision schema.

=head1 REVISION METHODS

=over

=item $obj = $revision-E<gt>module_object

This method returns the object represented byt he node's module field. This method will call the module's C<fetch()> method to retrieve the object for this revision.

=cut

sub module_object {
	my $self = shift;
	my $p = shift;
	my $node = $self->node($p);
	return $node->{module}->fetch($self->id, $p);
}

=item $revision-E<gt>touch

This method should be called whenever a node module calls save. This should be performed within a transaction so that the update to node, revision, and module all succeed or all fail. This method automatically calls C<Contentment::Content::Node::touch>, so the module should not.

=cut

sub touch {
	my $self = shift;
	my $p    = shift;

	my $node = $self->node($p);
	$node->touch($p);
	$self->save($p);
}

=item $revision-E<gt>revive

This method causes this revision to become the "current" revision for the node.

=cut

sub revive {
	my $self = shift;

	$self->global_datasource_handle->begin_work;

	my $node = $self->node;
	$node->{head_revision_id} = $self->id;
	$node->save;
	$self->save;

	$self->global_datasource_handle->commit;
}

=back

=head1 SEE ALSO

L<Contentment::Content::VFS>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
