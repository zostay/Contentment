package Contentment::Content::Node;

use strict;
use warnings;

our $VERSION = '0.02';

use Carp;
use DateTime;
use Log::Log4perl;
use SPOPS::Initialize;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::Content::Node - Handy module for storing common data

=head1 DESCRIPTION

Borrowing from so many other content management systems (esp. Drupal and Everything), the node concept is that most content can be treated similarly. All content records are associated with the node. When creating content in other modules, content modules should create a node object and refer to it for generic content information.

Overall this module is a bit primitive and doesn't offer much. I'm still building it up to the pinacle of glory it should eventually assume.

=head1 NODE DATA

TODO Add documentation for the Node schema.

=cut

my %spops = (
	node => {
		class			=> 'Contentment::Content::Node',
		isa				=> [ qw/ Contentment::SPOPS / ],
		ruleset_from	=> [ qw/ SPOPSx::Tool::DateTime / ],
		base_table		=> 'node',
		field			=> [ qw/
			node_id
			head_node_rev_id
			module
			path
			enabled
			node_owner
			node_group
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
		has_a			=> { 'Contentment::Content::Revision' => 'head_node_rev_id' },
		links_to		=> { 'Contentment::Content::Revision' => 'revision' },
	},
	revision => {
		class			=> 'Contentment::Content::Revision',
		isa				=> [ qw/ Contentment::SPOPS / ],
		ruleset_from	=> [ qw/ SPOPSx::Tool::DateTime / ],
		base_table		=> 'revision',
		field			=> [ qw/
			node_rev_id
			revision_id
			node_id
			ctime
			creator
			mtime
			updater
			dtime
			deleter
		/ ],
		id_field		=> 'node_rev_id',
		increment_field	=> 1,
		datetime_format	=> {
			ctime => 'DateTime::Format::MySQL',
			mtime => 'DateTime::Format::MySQL',
			ctime => 'DateTime::Format::MySQL',
		},
		has_a			=> { 'Contentment::Content::Node' => 'node_id' },
	},
);

SPOPS::Initialize->process({ config => \%spops });

__PACKAGE__->_create_table('MySQL', 'node', q(
	CREATE TABLE node (
		node_id			INT(11) NOT NULL AUTO_INCREMENT,
		current_node_rev_id	INT(11),
		module			VARCHAR(100) NOT NULL,
		path			VARCHAR(255),
		enabled			INT(1) NOT NULL,
		node_owner		VARCHAR(150) NOT NULL,
		node_group		VARCHAR(150) NOT NULL,
		ctime			DATETIME NOT NULL,
		creator			VARCHAR(150) NOT NULL,
		mtime			DATETIME NOT NULL,
		updater			VARCHAR(150) NOT NULL,
		dtime			DATETIME,
		deleter			VARCHAR(150),
		PRIMARY KEY (node_id), 
		UNIQUE (path));
));

__PACKAGE__->_create_table('MySQL', 'revision', q(
	CREATE TABLE revision (
		node_rev_id		INT(11) NOT NULL AUTO_INCREMENT,
		node_id			INT(11) NOT NULL,
		revision_id		INT(11) NOT NULL,
		ctime			DATETIME NOT NULL,
		creator			VARCHAR(150) NOT NULL,
		mtime			DATETIME NOT NULL,
		updater			VARCHAR(150) NOT NULL,
		dtime			DATETIME,
		deleter			VARCHAR(150),
		PRIMARY KEY (node_rev_id),
		UNIQUE (node_id, revision_id));
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
	$self->module_object->get_security(@_);
}

sub _node_update {
	my $self = shift;
	my $p    = shift;

	my $now = DateTime->now;

	if ($p->{is_add}) {
		$self->{ctime} = $now;
		$self->{creator} = $Contentment::context->current_user->id;
		$self->{mtime} = $now;
		$self->{updater} = $Contentment::context->current_user->id;
	}
	
	if ($self->{enabled}) {
		$self->{mtime} = $now;
		$self->{updater} = $Contentment::Context->current_user->id;
	} else {
		$self->{dtime} = $now;
		$self->{deleter} = $Contentment::Context->current_user->id;
	}

	return __PACKAGE__;
}

sub ruleset_factory {
	my ($class, $rs_table) = @_;
	push @{ $rs_table->{pre_save_action} }, \&_node_update;
	return __PACKAGE__;
}

=head1 NODE METHODS

In order to make this API a little more usable, several features have been added to the typical SPOPS features.

=over

=item $obj = $node-E<gt>module_object

This method returns the object represented by the node's module field. This method will call the module's C<load_node_revision()> method to retrieve the object for the head revision.

=cut

sub module_object {
	my $self = shift;
	$self->{module}->load_node_revision($self->{head_node_rev_id});
}

=item $node-E<gt>touch

This method should not be called directly as it is called the C<Contentment::Content::Revision::touch>. This method calls the C<save> method to trigger time and user field updates.

=cut

sub touch {
	my $self = shift;
	$self->save;
}

=back

=cut

package Contentment::Content::Revision;

sub get_security {
	my $self = shift;
	$self->module_object->get_security(@_);
}

sub _node_update {
	my $self = shift;
	my $p    = shift;

	my $now = DateTime->now;

	if ($p->{is_add}) {
		$self->{ctime} = $now;
		$self->{creator} = $Contentment::context->current_user->id;
		$self->{mtime} = $now;
		$self->{updater} = $Contentment::context->current_user->id;
	}
	
	if ($self->{enabled}) {
		$self->{mtime} = $now;
		$self->{updater} = $Contentment::Context->current_user->id;
	} else {
		$self->{dtime} = $now;
		$self->{deleter} = $Contentment::Context->current_user->id;
	}

	return __PACKAGE__;
}

sub ruleset_factory {
	my ($class, $rs_table) = @_;
	push @{ $rs_table->{pre_save_action} }, \&_node_update;
	return __PACKAGE__;
}


=head1 REVISION DATA

TODO Add documentation for the Revision schema.

=head1 REVISION METHODS

=over

=item $obj = $revision-E<gt>module_object

This method returns the object represented byt he node's module field. This method will call the module's C<load_node_revision()> method to retrieve the object for this revision.

=cut

sub module_object {
	my $self = shift;
	$self->node->{module}->load_node_revision($self->{node_rev_id});
}

=item $revision-E<gt>touch

This method should be called whenever a node module calls save. This should be performed within a transaction so that the update to node, revision, and module all succeed or all fail. This method automatically calls C<Contentment::Content::Node::touch>, so the module should not.

=cut

sub touch {
	my $self =shift;
	$self->node->touch;
	$self->save;
}

=item $revision-E<gt>revive

This method causes this revision to become the "current" revision for the node.

=cut

sub revive {
	my $self = shift;

	$self->global_datasource_handle->begin_work;

	my $node = $self->node;
	$node->{current_node_rev_id} = $self->id;
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
