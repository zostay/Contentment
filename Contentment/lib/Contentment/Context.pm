package Contentment::Context;

use strict;
use warnings;

use base 'Class::Accessor';

use Contentment::Form;
use Contentment::Panel;
use Contentment::Setting;
use DateTime;
use Log::Log4perl;
my $log = Log::Log4perl->get_logger('Contentment::Context');

our $VERSION = '0.02';

my @letters = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9' );

__PACKAGE__->mk_ro_accessors(qw/ url m r vfs setting /);
__PACKAGE__->mk_accessors(qw/ original_kind panel panels submission submissions last_processed session session_id /);

=head1 NAME

Contentment::Context - Starting point for information about the current request

=head1 DESCRIPTION

For Mason components in Contentment, the C<$context> variable is set to this singleton object. Perl modules can use the variable C<$Contentment::context>.

Primarily, the class provides a container to get at other more useful objects. As of this writing, some amount of procedural code is also dropped here for convienence, but it will probably be moved sooner or later.

=head1 READ-ONLY ACCESSORS

The following read-only accessors are defined:

=over

=item $context-E<gt>url

This returns the URL used to initiate the current request.

=item $context-E<gt>session_id

This returns the session ID associated with the current request.

=item $context-E<gt>session

This returns the session data associated with the current request. Changes to this data will be saved at the end of request handling.

=item $context-E<gt>m

This returns the L<HTML::Mason::Request> object used to process the top Mason request.

=item $context-E<gt>r

This returns the L<Apache::Request> object associated with the top Mason request.

=item $context-E<gt>vfs

This is a shortcut to performing: C<Contentment::VFS->new>.

=item $context-E<gt>setting

This is a link to the L<Contentment::Setting> object, which can be used by plugins to store settings and other miscellaneous information.

=back

=head1 READ-WRITE ACCESSORS

The following accessors may be modified to update the context object. To modify a value you may just pass the modifications into the accessor. See L<Class::Accessor> for details.

=over

=item $context-E<gt>original_kind

This is used to set the original kind the transformation system will try to transform the overall request from.

=item $context-E<gt>panel

This is the top-level panel that has been defined by the response. Don't mess with this unless you I<really> know what you're doing.

=item $context-E<gt>panels

This is a stack of panels in case of nested panels. Don't mess with this unless you I<really> know what you're doing.

=item $context-E<gt>submission

This is the top-level submission object defined by the response. Don't mess with this unless you I<really> know what you're doing.

=item $context-E<gt>submissions

This is a stack of submissions in case of nested forms. Don't mess with this unless you I<really> know what you're doing.

=item $context-E<gt>last_processed

This is a list of form submission UUIDs that were processed by an immediately preceding C</content/widget/process.mason> run, which redirected to the current request.

=back

=head1 OTHER API

Here is a description of the other available methods.

=over

=item $context = Contentment::Context-E<gt>new($url, $session_id, $session, $m, $r)

Don't use this unless your're defining a new front-end to Contentment. This is used internally to initially create the context.

=cut

sub error_map {
	my $result = shift;
	die "No map defined.";
}

# Create a new context
sub new {
	my ($class, $args) = @_;
	my $url        = $args->{url};
	my $session_id = $args->{session_id};
	my $session    = $args->{session};
	my $m          = $args->{m};
	my $r          = $args->{r};

	my $setting = Contentment::Setting->fetch(__PACKAGE__);
	unless (defined $setting) {
		$setting = Contentment::Setting->new;
		$setting->{namespace} = __PACKAGE__;
		$setting->{data} = {};
	}

	$class->SUPER::new({
		url            => $url,
		session_id     => $session_id,
		session        => $session,
		m              => $m,
		r              => $r,
		original_kind  => 'unknown',
		vfs            => Contentment::VFS->new,
		panel          => Contentment::Panel->new(
			$url,
			'__DEFAULT__',
			'Contentment::Context::error_map',
		),
		panels         => [],
		setting	       => $setting,
		submissions    => [],
		last_processed => $args->{last_processed} || [],
	});
}

=item $context-E<gt>current_user

Fetches the user object associated with the user's current session. This is just a convenient short-cut for C<$context->session->{current_user}>.

=cut

sub current_user {
	return shift->session->{current_user};
}

=item $context-E<gt>last_processed_for_form($form_name)

Returns all the Form Submission objects in an array reference matching UUIDs in C<last_processed> that belong to the named form.

=cut

sub last_processed_for_form {
	my $self      = shift;
	my $form_name = shift or die "Missing required 'form_name' argument.";

	my @results;
	for my $uuid (@{ $self->last_processed }) {
		my $submission = Contentment::Form::Submission->fetch($uuid);
		push @results, $submission if $submission->{form_name} eq $form_name;
	}

	return \@results;
}

=item $context-E<gt>action_result($state, %args)

DEPRECATED: Don't use this. This was used by the forms system and will be removed entirely in the very near future.

=cut

# Creates a return value to be used as the output state of an action.
sub action_result {
	my ($self, $state, %args) = @_;
	warn "DEPRECATION: Use Contentment::Action::Result::new instead.";
	return Contentment::Action::Result->new(
		state => $state, 
		args => \%args
	);
}

=item $context-E<gt>start_panel($panel)

Takes a L<Contentment::Panel> and makes it the current panel. If this panel is nested, then it pushes the last panel onto the panels stack.

=cut

sub start_panel {
	my ($self, $panel) = @_;

	push @{ $self->panels }, $self->panel;
	$self->panel($panel);
}

=item $test = $context-E<gt>has_panel

Returns true if the response has defined a panel. (There is always a top-level panel named __DEFAULT__, this one doesn't count.)

=cut

sub has_panel {
	my $self = shift;
	$self->panel->name ne '__DEFAULT__';
}

=item $context-E<gt>end_panel

Pops the top-most panel from the panels stack.

=cut

sub end_panel {
	my $self = shift;

	$self->panel(pop @{ $self->panels });
}

# =item $context-E<gt>form_submission($form, $submission)
# 
# Given a form or form name (C<$form>) and a submission or submission UUID (C<$submission>), this notifies the system that the next time this user's session encounters the given form, the given submission should be reused. If no such submission can be found or the submission's characteristics do not match the form, then a new submission will be created anyway.
# 
# =cut
# 
# sub form_submission {
# 	my $self       = shift;
# 	my $form       = shift;
# 	my $submission = shift;
# 
# 	$form       = $form->{form_name}  if ref $form;
# 	$submission = $submission->{uuid} if ref $submission;
# 
# 	$self->session->{forms}{$form}{use_submission} = $submission;
# }

=item $test = $context-E<gt>is_top_submission

Returns true when we are inside of exactly one submission (i.e., not in a submission nested within another).

=cut

sub is_top_submission {
	my $self = shift;

	return $self->submission && !@{ $self->submissions };
}

=item $context-E<gt>start_form(name => $name, action => $action, default_map => $default_map, resume => $resume)

Attempts to load an existing submission if C<$resume> is not false or pushes a new form submission onto the submissions stack. The form is either loaded from the database or a new one named C<$name> is created. The C<$action> is used to set the action for the form. A new submission is created and pushed onto the submissions stack. This submission will have the the panel's map associated with it if a panel has been defined, otherwise it will fallback to the C<$default_map>.

=cut

sub start_form {
	my $self = shift;
	my %args = @_;

	my $name   = $args{name}   or die "Missing required argument name.";
	my $action = $args{action} or die "Missing required argument action.";
	my $map    = $args{default_map} or die "Missing required argument default_map.";
	my $resume = $args{resume} || 1;

	my $form;
	
	# Reopen seen form or declare a new one
	unless ($form = Contentment::Form->fetch($name)) {
		$form = Contentment::Form->new;
		$form->{form_name} = $name;
	}

	$form->{action}    = $action;
	$form->save;
	
	# Set the submission map from the panel or fall back to defaults.
	$map = $self->panel->map if ($self->has_panel);

	# Setup the current submission for rendering.
	# Save the last submission to be restored in the case of nested forms.
	$self->submission
		&& push @{ $self->submissions }, $self->submission;

	# Load an existing submission if this form is resumeable.
	my $submission;
	if ($resume) {
		for my $uuid (@{ $self->last_processed }) {
			$submission = Contentment::Form::Submission->fetch($uuid);
			$submission->{form_name} eq $name              or undef $submission;
			$submission->{session_id} eq $self->session_id or undef $submission;
			!defined $submission->{ftime}                  or undef $submission;
			$submission->{map} eq $map                     or undef $submission;
		}
	}

	# Otherwise, create a new submission.
	unless (defined $submission) {
		$submission = Contentment::Form::Submission->new;
		$submission->{form_name}  = $name;
		$submission->{session_id} = $self->session_id;
		$submission->{map}        = $map;
		$submission->{ctime}      = DateTime->now;
		$submission->save;
	}

	# Make sure the transient "alias" variable is always appropriately set.
	$submission->{alias}     = $self->form_alias;

	# Make the loaded/new submission The Submission.
	$self->submission($submission);
}

=item $alias = $context-E<gt>form_alias

This is used internally to modify the names of all widgets written to the client to differentiate nested forms from one another.

=cut

sub form_alias {
	my $self = shift;
	my $nested_submissions = scalar(@{ $self->submissions });
	if ($nested_submissions) {
		return "$nested_submissions.";
	} else {
		return "";
	}
}

=item $context-E<gt>end_form

Pops the top-most submission off of the submissions stack.

=cut

sub end_form {
	my $self = shift;

	$self->submission(pop @{ $self->submissions });
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
