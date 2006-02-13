package Contentment::Form::Submission;

use strict;
use warnings;

our $VERSION = '0.10';

use base 'Oryx::Class';

use Class::Date qw( now );
use Data::UUID;

=head1 NAME

Contentment::Form::Submission - Persistent store for form submissions

=head1 DESCRIPTION

This class is used internally by L<Contentment::Form>. Don't mess with it. Really, don't.

=cut

our $schema = {
    attributes => [ {
            name => 'submission_id',
            type => 'String',
        }, {
            name => 'session_id',
            type => 'String',
        }, {
            name => 'username',
            type => 'String',
        }, {
            name => 'results',
            type => 'Complex',
        }, {
            name => 'errors',
            type => 'Complex',
        }, {
            name => 'is_activated',
            type => 'Boolean',
        }, {
            name => 'is_finished',
            type => 'Boolean',
        }, {
            name => 'created_on',
            type => 'DateTime',
        }, {
            name => 'updated_on',
            type => 'DateTime',
        }, {
            name => 'activated_on',
            type => 'DateTime',
        }, {
            name => 'finished_on',
            type => 'DateTime',
        },
    ],
    associations => [ {
            role  => 'definition',
            type  => 'Reference',
            class => 'Contentment::Form::Definition',
        }, 
    ],
};

sub create {
    my $class = shift;
    my $args  = shift;

    my $uuid = Data::UUID->new;

    my $context = Contentment->context;

    # Set defaults
    $args->{submission_id} = $uuid->create_str;
    $args->{session_id}    = $context->session_id;
    $args->{username}      = $context->security->get_principal->username;
    $args->{results}       = {};
    $args->{errors}        = {};
    $args->{is_activated}  = 0;
    $args->{is_finished}   = 0;
    $args->{created_on}    = now;
    $args->{updated_on}    = now;

    return $class->SUPER::create($args);
}

sub update {
    my $self = shift;
    
    # Update dates
    $self->updated_on(now);
    $self->activated_on(now) if $self->is_activated;
    $self->finished_on(now)  if $self->is_finished;

    return $self->SUPER::update(@_);
}

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
