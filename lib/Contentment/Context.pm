package Contentment::Context;

use strict;
use warnings;

use Log::Log4perl;
my $log = Log::Log4perl->get_logger('Contentment::Context');

our $VERSION = '0.01';

my @letters = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9' );

# Create a new context
sub new {
	my ($class, $session_id, $session, $m, $r) = @_;

	bless { 
		session_id => $session_id,
		session => $session, 
		m => $m, 
		r => $r, 
		original_kind => 'unknown',
		vfs => Contentment::VFS->new,
	}, $class;
}

sub vfs {
	return shift->{vfs};
}

sub session_id {
	return shift->{session_id};
}

sub session {
	return shift->{session};
}

sub m {
	return shift->{m};
}

sub r {
	return shift->{r};
}

sub current_user {
	return shift->{session}->{session_data}{current_user};
}

# Creates a return value to be used as the output state of an action.
sub action_result {
	my ($self, $state, %args) = @_;
	return { state => $state, args => \%args };
}

# Returns the current form ID
sub form_id {
	my $self = shift;
	my $session = $$self{session};
	$$session{form_id};
}

sub start_panel {
	my ($self, $uri, $name, $map) = @_;
	my $session = $$self{session};

	push @{$$session{panels}}, $$session{panel};
	$$session{panel} = { uri => $uri, name => $name, map => $map };
}

sub has_panel {
	my $self = shift;
	my $session = $$self{session};
	exists $$session{panel} && defined $$session{panel};
}

sub panel_name {
	my $self = shift;
	my $session = $$self{session};
	$$session{panel}{name};
}

sub panel_map {
	my $self = shift;
	my $session = $$self{session};
	$$session{panel}{map};
}

sub end_panel {
	my $self = shift;
	my $session = $$self{session};
	$$session{panel} = pop @{$$session{panels}};
}

sub generate_form_id {
	join '', map $letters[int(rand(62))], ( 1 .. 5 );
}

# Creates a form ID, associates a action with that ID, pushes any existing form
# ID down one level and makes the new form ID the current one
sub start_widget_action {
	my ($self, $action, $default_uri, $default_map) = @_;
	my $session = $$self{session};

	push @{$$session{form_ids}}, $$session{form_id} 
		if defined $$session{form_id};
	$$session{form_id} = generate_form_id;
	$$session{actions}{$$session{form_id}} = {
		action => $action,
		uri    => $$session{panel}{uri} || $default_uri,
		panel  => $$session{panel}{name} || "__DEFAULT__",
		map    => $$session{panel}{map} || $default_map,
	};
}

# Determines if we're exactly one form level deep
sub is_top_form {
	my $self = shift;
	my $session = $$self{session};
	defined $$session{form_id} 
		&& (!defined $$session{form_ids} || !@{$$session{form_ids}});
}

# Pops the form ID from the list and makes the previous form ID current
sub end_widget_action {
	my $self = shift;
	my $session = $$self{session};

	$$session{form_id} = pop @{$$session{form_ids}};
}

# Returns all known form IDs
sub forms {
	my $self = shift;
	my $session = $$self{session};
	keys %{ $$session{actions} }
}

# Adds a widget to the current form
sub add_widget {
	my ($self, %args) = @_;
	my $session = $$self{session};
	my $name = $args{name};
	$args{form_id} = $self->form_id;

	$$session{widgets}{$$session{form_id}}{$name} = \%args;
}

# Returns all widgets for the given form ID
sub widgets {
	my ($self, $form) = @_;
	my $session = $$self{session};
	values %{ $$session{widgets}{$form} };
}

# Returns the action for the given form ID
sub get_action {
	my ($self, $form_id) = @_;
	my $session = $$self{session};
	$$session{actions}{$form_id};
}

# Returns all the form values set for the given form ID
sub form_values {
	my ($self, $form_id) = @_;
	my $session = $$self{session};
	return () unless defined $$session{values}{$form_id};
	%{ $$session{values}{$form_id} };
}

# Adds a value to the form values hash
sub add_form_value {
	my ($self, $form_id, $name, $value) = @_;
	my $session = $$self{session};
	$$session{values}{$form_id}{$name} = $value;
}

sub set_action_result {
	my ($self, $uri, $panel, $map, $result) = @_;
	my $session = $$self{session};
	$$session{results}{$uri}{$panel} = {
		result => $result,
		map    => $map,
	};
}

sub get_action_result {
	my ($self, $uri, $panel) = @_;
	my $session = $$self{session};
	$$session{results}{$uri}{$panel}{result};
}

sub get_action_map {
	my ($self, $uri, $panel) = @_;
	my $session = $$self{session};
	$$session{results}{$uri}{$panel}{map};
}

sub delete_action_result {
	my ($self, $uri, $panel) = @_;
	my $session = $$self{session};
	delete $$session{results}{$uri}{$panel};
}

sub original_kind {
	my ($self, $original) = @_;
	
	if (defined $original) {
		$log->debug("Context changing original kind from $self->{original_kind} to $original");
		$self->{original_kind} = $original;
	}
	return $self->{original_kind};
}

1
