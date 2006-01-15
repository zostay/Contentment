package Contentment::Security::Role;

use strict;
use warnings;

our $VERSION = '0.05';

use base 'Oryx::Class';

=head1 NAME

Contentment::Security::Role - Contentment security roles

=head1 DESCRIPTION

=cut

sub name { 'security_role' }

our $schema = {
	attributes => [ {
			name => 'title',
			type => 'String',
		}, {
			name => 'description',
			type => 'String',
		}, {
			name => 'is_special',
			type => 'Boolean',
    }, ],
	associations => [
		{
			role  => 'permissions',
			class => 'Contentment::Security::Permission',
			type  => 'Array',
		},
	],
};

sub fetch_permission_options {
    return [
        map { [
            $_->id,
            q(<a href="admin/permissions/edit.html?id=).$_->id.q(">)
                .$_->title.q(</a>),
            $_->description,
        ] }
        Contentment::Security::Permission->search
    ];
}

sub process_edit_form {
    my $submission = shift;
    my $results    = $submission->results;

    # They've asked for an update
    if ($results->{submit} eq 'Update') {

        # Are we editting?
        if ($results->{id}) {
            my $role = Contentment::Security::Role->retrieve($results->{id});

            $role->title($results->{title});
            $role->description($results->{description});

            @{ $role->permissions }
                = grep { defined $_ }
                  map  { Contentment::Security::Permission->retrieve($_) }
                      @{ $results->{permissions} };

            $role->update;
            $role->commit;
        }

        # Are we creating?
        else {
            my $role = Contentment::Security::Role->create({
                title       => $results->{title},
                description => $results->{description},
            });

            @{ $role->permissions }
                = grep { defined $_ }
                  map  { Contentment::Security::Permission->retrieve($_) }
                      @{ $results->{permissions} };

            $role->update;
            $role->commit;
        }
    }

    # They cancled.
    # else { do nothing }
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut 

1
