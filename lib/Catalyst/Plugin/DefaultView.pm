package Catalyst::Plugin::DefaultView;

use strict;
use warnings;

our $VERSION = '0.01';

use Catalyst;

=head1 NAME

Catalyst::Plugin::DefaultView - Picks a default view plugin if none chosen

=head1 SYNOPSIS

  # In MyApp.pm
  use Catalyst qw/ -Debug DefaultView /;

=head1 DESCRIPTION

Chooses which view should be used by a given request automatically, if none is already chosen by the action. 

This is very similar to the L<Catalyst::Plugin::DefaultEnd>, but offers additional functionality for picking from a variety of views. Some of the actual logic is borrowed from there, though.

=head2 METHODS

=over

=item $c-E<gt>default_view

Examines the context and tries to determine which view is the appropriate one for the current request. This is done by checking the "template" field of the stash and trying to determine the appropriate view for that template type. If no template has been set, then this method will return C<undef>. Thus, if you want a view to be picked automatically, you must set the "template" field in the stash.

=cut

# XXX This is all hard-coded. Configuration!
sub default_view {
    my $c = shift;

    my $template;
    if ($template = $c->stash->{template}) {
        my $view;
        if ($template =~ /\.tt2?$/i) {
            $view = $c->view('TT');
        }

        elsif ($template =~ /\.(?:php[345]?|pht(?:ml?)?)$/i) {
            $view = $c->view('PHP');
        }

        elsif ($template =~ /\.(?:mht(?:ml?)?|mas(?:on)?)$/i) {
            $view = $c->view('Mason');
        }

        $c->log->debug("default_view(): ", defined $view ? ref $view : undef);

        return $view;
    }

    else {
        return undef;
    }
}

=item end

This provides a default end handler for the application. It will attempt to find a view appropriate for the current request using the C<default_view> method and will run it. Otherwise, it does nothing.

=cut

sub end : Private {
    my ($self, $c) = @_;

    # Check for debugging
    die "forced debug" if $c->debug && $c->req->params->{dump_info};

    # Don't bother if template hasn't been set
    return 1 if !$c->stash->{template};
    
    # Stop if we're redirecting
    return 1 if $c->response->status =~ /^3\d\d$/;

    # Sweet! Let's see if we need to come up with a view.
    my $view = $c->default_view;

    # No view. Good-bye!
    return 1 unless defined $view;

    # View it!
    return $c->forward($view);
}

=back

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
