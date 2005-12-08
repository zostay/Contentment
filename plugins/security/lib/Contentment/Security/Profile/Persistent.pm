package Contentment::Security::Profile::Persistent;

use strict;
use warnings;

our $VERSION = '0.05';

use base 'Oryx::Class';

=head1 NAME

Contentment::Security::Profile::Persistent - profile info that persists

=head1 DESCRIPTION

This class defines a profile implementation (see L<Contentment::Security::Profile> for the interface) that is stored in the L<Oryx> storage (see L<Contentment::Oryx>).

=cut

sub name { 'security_profile' }

our $schema = {
    attributes => [
        {
            name => 'username',
            type => 'String',
        },
        {
            name => 'password',
            type => 'String',
        },
        {
            name => 'full_name',
            type => 'String',
        },
        {
            name => 'email_address',
            type => 'String',
        },
        {
            name => 'web_site',
            type => 'String',
        },
        {
            name => 'information',
            type => 'Complex',
        },
        {
            name => 'preferences',
            type => 'Complex',
        },
    ],
    associations => [
        {
            role  => 'roles',
            type  => 'Array',
            class => 'Contentment::Security::Role',
        },
    ],
};

sub fetch_role_options {
    Contentment::Security->check_permission(
        'Contentment::Security::Manager::assign_roles');

    return [
        map { [ 
                $_->id, 
                q(<a href="admin/roles/edit.html?id=).$_->id.q(">)
                    .$_->title.q(</a>), 
                $_->description 
            ] } 
            Contentment::Security::Role->search({ is_special => 0 })
    ];
}

sub process_edit_form {
    Contentment::Security->check_permission(
        'Contentment::Security::Manager::manage_users');

    my $submission = shift;
    my $results    = $submission->results;

    # They've asked for an update
    if ($results->{submit} eq 'Update') {

        # Are we creating or editting?
        if ($results->{id}) {

            # Make sure we modify the current profile correctly to prevent our
            # changes from being clobbered by the security manager's routine
            # updates
            my $profile;
            if ($results->{id} 
            == Contentment::Security->get_principal->profile->id) {
                $profile = Contentment::Security->get_principal->profile;
            } else {
                $profile 
                    = Contentment::Security::Profile::Persistent
                        ->retrieve($results->{id});
            }

            $profile->username($results->{username});
            $profile->password($results->{password}) if $results->{password};
            $profile->full_name($results->{full_name});
            $profile->email_address($results->{email_address});
            $profile->web_site($results->{web_site});

            if (Contentment::Security->has_permission(
            'Contentment::Security::Manager::assign_roles')) {
                @{ $profile->roles }
                    = grep { defined $_ }
                    map  { Contentment::Security::Role->retrieve($_) }
                        @{ $results->{roles} };
            }

            $profile->update;
            $profile->commit;

        }

        # Creating a new user
        else {
            my $profile = Contentment::Security::Profile::Persistent->create({
                username => $results->{username},
                password => $results->{password},
                full_name => $results->{full_name},
                email_address => $results->{email_address},
                web_site => $results->{web_site},
            });

            if (Contentment::Security->has_permission(
            'Contentment::Security::Manager::assign_roles')) {
                @{ $profile->roles }
                    = grep { defined $_ }
                    map  { Contentment::Security::Role->retrieve($_) }
                        @{ $results->{roles} };
            }

            $profile->update;
            $profile->commit;
        }
    }

    # They've canceled
    else {
        # do nothing
    }
}

=cut

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
