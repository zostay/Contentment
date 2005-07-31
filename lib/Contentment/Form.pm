package Contentment::Form;

use strict;
use warnings;

our $VERSION = '0.04';

use Contentment;
use Contentment::SPOPS;
use Data::UUID;
use DateTime::Format::DBI;
use Log::Log4perl;
use SPOPS::Initialize;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::Form - Defines forms, widgets, and submissions API

=head1 DESCRIPTION

The forms API is divided into three primary and persistently stored types: C<Contentment::Form>, C<Contentment::Form::Widget>, and C<Contentment::Form::Submission>. This module currently contains the definition of all three. It is likely that the widget and submission API will be moved into their own modules at some future point. However, L<Contentment::Form> will likely remain the only module you need to load to get access to those classes.

The basic overview is that a "form" is the structure a particular web form takes, i.e., a collection "widgets." The "widgets" are the controls added to a form and provide processing to convert raw variables submitted over HTTP into processed values. The "submission" represents either a prepared form (a particular instance sent to the client) or a submitted form containing raw variables for processing. The submission asks each widget in the form to process the raw variables into processed values. Then, the form's action is asked to do whatever it does on those processed values.

=over

=item Contentment::Form

This class currently only contains two fields per record: C<form_name> and C<action>. The key, C<form_name>, should be a name unique to that form throughout the entire Contentment web site. This is used to group widgets and submissions together with that particular form. The C<action> is the name of the plugin (see L<Contentment/run_plugin>), which is responsible for processing a form submission from this form.

=item Contentment::Form::Widget

This class defines a C<form_name> and C<widget_name> that are able to uniquely identify each widget---though, in the database, the primary key is the C<widget_id>. The widget then has a C<class> field, in which is stored the name of a class used for processing the widget. That class must define a single C<process> method, which is called with the widget and submission as arguments. Finally, the C<args> field defines the characteristics of the widget as a hash reference.

=item Contentment::Form::Submission

Submissions form the capstone of the API. Each submission has a C<uuid>, C<form_name>, C<session_id>, C<ctime>, C<ptime>, C<ftime>, C<map>, C<vars>, and C<results>. The C<uuid> is an automatically generated (see L<Data::UUID>) identifier for the submission, which is used to creating forms and for determining which submission is responsible for handling a form submission. The C<form_name> tells the submission which form object it belongs to and, consequently, which widgets apply to it. The C<session_id> is a security feature, which prevents a non-superuser from trying to steal information out of another session's submission. The C<ctime> is a L<DateTime> object containing the submission's creation timestamp. The C<ptime> is a L<DateTime> object contain the timestamp from the last time it was processed (i.e., the last time a submission was made to modify the C<vars>). The C<ftime> is a L<DateTime> object containing the timestamp from when the submission was last processed and the action executed reported a "finished" state. The C<map> names the plugin used to determine which URL to load based upon the state of the submission. The C<vars> is a hash reference containing the processed form values. The C<results> is used to store the output from the last executed C<action>.

=back

=cut

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
		rules_from			=> [ qw/ SPOPSx::Tool::YAML / ],
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
		yaml_fields			=> [ 'args' ],
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
		rules_from			=> [ qw/ SPOPSx::Tool::YAML SPOPSx::Tool::DateTime / ],
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
		yaml_fields         => [ qw/ vars results / ],
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

=head1 EXTRA METHODS

=over

=item @submissions = Contentment::Form::Submission-E<gt>create_from_args(%args)

This method attempts to load submission objects from a submitted form. The submissions will have the transient variable C<alias> set to the alias assigned by the submitter and the C<raw_vars> hash will contain the raw values submitted.

=cut

sub Contentment::Form::Submission::create_from_args {
	my $class   = shift;
	my %ARGS    = @_;

	$log->is_debug &&
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

		$log->is_debug &&
			$log->debug("Detected form submission with UUID $uuid with activation $activated.");

		my $submission = Contentment::Form::Submission->fetch($uuid);
		if (!$submission) {
			# TODO Better error handling here.
			warn "Unknown Form Submission UUID: $uuid given.";
			next;
		}

		if ($submission->{session_id} ne Contentment->context->session_id) {
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

=item $url = $submission->process

This method performs form processing. It runs each form widget against the raw values submitted to the form and then executes the action associated with the form. Finally, it asks the map plugin for a URL and returns the URL.

=cut

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
		push @{ Contentment->context->last_processed }, $self->{uuid};
	} else {
		$self->{ptime} = DateTime->now;
		$self->save;
	}

	return Contentment->run_plugin($self->{map}, Contentment->context);
}

=item $widget = Contentment::Form::Widget->build(%args)

This is a shortcut for creating widgets. This method will attempt to load the widget from the C<form_name> and C<widget_name> arguments passed into C<%args> if it can. If not it will create a new widget with those fields set. Then it will set the C<class> and C<args> fields of the widget according to the same values in C<%args>.

=cut

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

=item $widget->process($submission)

Applies the widget's C<class> processor to the given C<$submission>.

=cut

sub Contentment::Form::Widget::process {
	my $self       = shift;
	my $submission = shift;

	eval "use $self->{class}";
	warn "Could not load Widget class $self->{class}: $@" if $@;

	$self->{class}->process($self, $submission);
}

=back

=head1 SEE ALSO

L<Contentment::Form::Widget::Null>, L<Contentment::Form::Widget::Input>, L<Contentment::Form::Widget::Select>

=head1 AUTHOR

Andrew Sterling Hanenkamp E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1

