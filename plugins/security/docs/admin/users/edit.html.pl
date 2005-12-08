=begin meta
    description => 'Edit a user profile.'
    title       => 'User'
=end meta
=cut

Contentment::Security->check_permission(
    'Contentment::Security::Manager::manage_users');
    
my %args = @_;

#my $template = <<'END_OF_TEMPLATE';
#[% form.begin %]
#
#[% form.widgets.username.label.render %]      [% form.widgets.username.render %]<br/>
#[% form.widgets.password.label.render %]      [% form.widgets.password.render %]<br/>
#[% form.widgets.full_name.label.render %]     [% form.widgets.full_name.render %]<br/>
#[% form.widgets.email_address.label.render %] [% form.widgets.email_address.render %]<br/>
#[% form.widgets.web_site.label.render %]      [% form.widgets.web_site.render %]<br/>
#
#[% form.widgets.roles.render %]
#
#[% form.widgets.submit.render %]
#[% form.end %]
#END_OF_TEMPLATE
    
my $form = Contentment::Form->define({
    name      => 'Contentment::Security::Profile::Persistent::edit_form',
#    method    => 'POST',
    action    => 
        'Contentment::Security::Profile::Persistent::process_edit_form',
    activate  => 1,
#    template  => \$template,
#    modes     => {
#        modes   => [ qw( new edit delete ) ],
#        widgets => {
#            id => {
#                new => 0,
#            },
#            submit => {
#                new => {
#                    value => [ qw( Create Cancel ) ],
#                },
#                delete => {
#                    value => [ qw( Delete Cancel ) ],
#                },
#            },
#        },
#    },
    widgets   => [ 
        id => {
            name  => 'id',
            class => 'Hidden',
        },
        username => {
            name  => 'username',
            class => 'Text',
        },
        password => {
            name  => 'password',
            class => 'Text',
            type  => 'password',
        },
        full_name => {
            name  => 'full_name',
            class => 'Text',
        },
        email_address => {
            name  => 'email_address',
            class => 'Text',
        },
        web_site => {
            name  => 'web_site',
            class => 'Text',
        },
        Contentment::Security->has_permission(
            'Contentment::Security::Manager::asign_roles') ?
        (
            roles => {
                name        => 'roles',
                class       => 'TabularChoice',
                heading     => [ '' => qw( Title Description ) ],
                options_sub => 'Contentment::Security::Profile::Persistent'
                            .'::fetch_role_options',
            }
        ) : (),
        submit => {
            value => [ qw( Update Cancel ) ],
            class => 'Submit',
        }
    ],
});

if ($form->submission->is_finished) {
    Contentment::Response->redirect('admin/users/index.html')->generate;
}

elsif (my $id = $args{id} || $form->submission->results->{id}) {
    # Edit
    my $profile = Contentment::Security::Profile::Persistent
        ->retrieve($args{id} || $form->submission->results->{id});

    print $form->render({
        id            => $profile->id,
        username      => $profile->username,
        full_name     => $profile->full_name,
        email_address => $profile->email_address,
        web_site      => $profile->web_site,
        Contentment::Security->has_permission(
            'Contentment:Security::Manager::assign_roles')
        ? (roles         => [ map { $_->id } @{ $profile->roles } ])
        : (),
    });
}

else {
    # New
    $form->render;
}
