package Contentment::Form;

use strict;
use warnings;

our $VERSION = '0.01';

use Contentment;
use Contentment::SPOPS;
use Data::UUID;
use DateTime::Format::DBI;
use Log::Log4perl;
use SPOPS::Initialize;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

my %spops = (
	form => {
		class				=> 'Contentment::Form',
		isa					=> [ qw/ Contentment::SPOPS / ],
		base_table			=> 'form',
		field				=> [ qw/ form_name action / ],
		id_field			=> 'form_name',
		no_update			=> 'form_name',
		no_security			=> 1,
		links_to			=> {
			'Contentment::Form::Submission' => 'form_submission',
			'Contentment::Form::Widget'     => 'form_widget',
		},
	},
	widget => {
		class				=> 'Contentment::Form::Widget',
		isa					=> [ qw/ Contentment::SPOPS / ],
		rules_from			=> [ qw/ SPOPSx::Tool::HashField / ],
		base_table			=> 'form_widget',
		field				=> [ qw/ 
			widget_id 
			form_name 
			widget_name 
			class 
			args 
		/ ],
		id_field			=> 'widget_id',
		increment_field		=> 1,
		hash_fields			=> [ 'args' ],
		no_insert			=> [ 'widget_id' ],
		no_update			=> [ qw/ widget_id form_name widget_name / ],
		no_security			=> 1,
		has_a				=> {
			'Contentment::Form' => 'form_name',
		},
	},
	submission => {
		class				=> 'Contentment::Form::Submission',
		isa					=> [ qw/ SPOPS::Key::UUID Contentment::SPOPS / ],
		rules_from			=> [ qw/ SPOPSx::Tool::HashField SPOPSx::Tool::DateTime / ],
		base_table			=> 'form_submission',
		field				=> [ qw/ uuid form_name session_id ctime ptime ftime map vars results / ],
		datetime_format     => {
			# FIXME This should use an instance of DateTime::Format::DBI, but that breaks while using
			# an undocumented DBI method.
			ctime => 'DateTime::Format::MySQL',
			ptime => 'DateTime::Format::MySQL',
			ftime => 'DateTime::Format::MySQL',
		},
		id_field			=> 'uuid',
		hash_fields         => [ qw/ vars results / ],
		no_security			=> 1,
		no_insert			=> [ 'uuid' ],
		has_a				=> {
			'Contentment::Form' => 'form_name',
		},
	},
);

SPOPS::Initialize->process({ config => \%spops });

Contentment::Form->_create_table('MySQL', 'form', q(
	CREATE TABLE form(
		form_name		CHAR(50) NOT NULL,
		action			CHAR(255) NOT NULL,
		PRIMARY KEY (form_name));
));

Contentment::Form::Widget->_create_table('MySQL', 'form_widget', q(
	CREATE TABLE form_widget(
		widget_id 		INT(11) AUTO_INCREMENT NOT NULL,
		form_name 		CHAR(50) NOT NULL,
		widget_name 	CHAR(50) NOT NULL,
		class 			CHAR(255) NOT NULL,
		args 			TEXT NOT NULL,
		PRIMARY KEY (widget_id),
		UNIQUE (form_name, widget_name));
));

Contentment::Form::Submission->_create_table('MySQL', 'form_submission', q(
	CREATE TABLE form_submission(
		uuid			CHAR(36) NOT NULL,
		form_name		CHAR(255) NOT NULL,
		session_id		CHAR(36) NOT NULL,
		ctime			DATETIME NOT NULL,
		ptime			DATETIME NULL,
		ftime			DATETIME NULL,
		map				CHAR(255) NOT NULL,
		vars			TEXT NOT NULL,
		results			TEXT NOT NULL,
		PRIMARY KEY (uuid));
));

sub Contentment::Form::Submission::create_from_args {
	my $class   = shift;
	my %ARGS    = @_;

	$log->debug("Loading submission from request.");

	my %forms;
	while (my ($key, $value) = each %ARGS) {
		if ($key =~ /^(\d+\.)?(\w+)$/) {
			my $alias = $1 || "";
			my $name  = $2;
			$forms{$alias}{$name} = $value;
		}
	}

	my @submissions;
	while (my ($alias, $form) = each %forms) {
		my $uuid       = delete $form->{__uuid__};
		my $activated  = delete $form->{__activate__} || 0;

		$log->debug("Detected form submission with UUID $uuid with activation $activated.");

		my $submission = Contentment::Form::Submission->fetch($uuid);
		if (!$submission) {
			# TODO Better error handling here.
			warn "Unknown Form Submission UUID: $uuid given.";
			next;
		}

		if ($submission->{session_id} ne $Contentment::context->session_id) {
			warn "Form Submission with UUID $uuid doesn't match this session, ignoring.";
			next;
		}

		$submission->{alias}     = $alias;
		$submission->{activated} = $activated;
		$submission->{raw_vars}  = $form;

		push @submissions, $submission;
	}

	return sort { $a->{alias} cmp $b->{alias} } @submissions;
}

sub Contentment::Form::Submission::process {
	my $self = shift;

	my $form = $self->form;

	for my $widget (@{ $form->widget }) {
		$widget->process($self);
	}

	if ($self->{activated}) {
		my $result = Contentment->run_plugin($form->{action}, $self);
		$self->{results} = $result;
		$self->{ptime} = DateTime->now;
		$self->{ftime} = DateTime->now if $result->{finished};
		$self->save;
		push @{ $Contentment::context->last_processed }, $self->{uuid};
	} else {
		$self->{ptime} = DateTime->now;
		$self->save;
	}

	return Contentment->run_plugin($self->{map}, $Contentment::context);
}

sub Contentment::Form::Widget::build {
	my $self = shift;
	my %args = @_;

	my $widgets = Contentment::Form::Widget->fetch_group({
		where => 'form_name = ? AND widget_name = ?',
		value => [ $args{form_name}, $args{widget_name} ],
	});

	my $widget;
	if (defined $widgets && @$widgets) {
		$widget = $widgets->[0];
	} else {
		$widget = Contentment::Form::Widget->new;
		$widget->{form_name}   = $args{form_name};
		$widget->{widget_name} = $args{widget_name};
	}

	$widget->{class} = $args{class};
	$widget->{args}  = $args{args};
	$widget->save;

	return $widget;
}

sub Contentment::Form::Widget::process {
	my $self       = shift;
	my $submission = shift;

	eval "use $self->{class}";
	warn "Could not load Widget class $self->{class}: $@" if $@;

	$self->{class}->process($self, $submission);
}

1;

__END__

=head1 NAME

Contentment::Form - Form handling API

=head1 DESCRIPTION

This module defines three different classes, C<Contentment::Form>, C<Contentment::Form::Widget>, and C<Contentment::Form::Submission>. Each of these are mainly used for the internal handling of form definitions and form
processing.

=head2 Contentment::Form

This class defines the structure a form has. This structure is essentially the action that should be performed on submission and the widgets associated with the form to process the incoming submission.

=head2 Contentment::Form::Widget

One widget object is associated with every control in the form. The widget depends on an external class to determine how it is rendered and processed.

=head2 Contentment::Form::Submission

When creating a form, a submission is used to establish a few basic facts about this particular form instance. When the client POSTs the form back to us, this is turned into an activated submission, which is processed by all widgets associated with the submissions form and then passed on to the action for final handling.

=head1 AUTHOR

Andrew Sterling Hanenkamp E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut
