=begin meta
    description => 'Edit a role.'
    title       => 'Role'
=end meta
=cut

$context->security->check_permission(
    'Contentment::Security::Manager::manage_roles');

my $self = shift;
my %args = @_;

my $form = $context->form->define({
    name     => 'Contentment::Security::Role::edit_form',
    action   => 'Contentment::Security::Role::process_edit_form',
    activate => 1,
    widgets  => [
        id => {
            name  => 'id',
            class => 'Hidden',
        },
        title => {
            name  => 'title',
            class => 'Text',
        },
        description => {
            name  => 'description',
            class => 'Text',
        },
        permissions => {
            name        => 'permissions',
            class       => 'TabularChoice',
            heading     => [ '' => qw( Title Description ) ],
            options_sub => 'Contentment::Security::Role::fetch_permission_options',
        },
        submit => {
            value => [ qw( Update Cancel ) ],
            class => 'Submit',
        },
    ],
});

if ($form->submission->is_finished) {
    $context->response->redirect('admin/roles/index.html')->generate;
}

elsif (my $id = $args{id} || $form->submission->results->{id}) {
    # Edit
    my $role = Contentment::Security::Role->retrieve(
        $args{id} || $form->submission->results->{id}
    );

    $self->properties->{title}       = $role->title;
    $self->properties->{description} = $role->description;

    print $form->render({
        id          => $role->id,
        title       => $role->title,
        description => $role->description,
        permissions => [ map { $_->id } @{ $role->permissions } ],
    });
}

else {
    # New
    $self->properties->{title}       = 'New Role';
    $self->properties->{description} = 'Create a new role.';

    $form->render;
}
