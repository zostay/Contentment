=begin meta
    description => 'Edit a blog.'
    title       => 'Blog'
=end meta
=cut

Contentment::Security->check_permission('Contentment::Node::Blog::edit_blogs');

my $self = shift;
my %args = @_;

my $form = Contentment::Form->define({
    name     => 'Contentment::Node::Blog::edit_form',
    action   => 'Contentment::Node::Blog::process_edit_form',
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
        content => {
            name  => 'content',
            class => 'TextArea',
        },
        submit => {
            value => [ qw( Update Cancel ) ],
            class => 'Submit',
        }
    ],
});

if ($form->submission->is_finished) {
    Contentment::Response->redirect('blog/index.html')->generate;
}

elsif (my $id = $args{id} || $form->submission->results->{id}) {
    # Edit
    my $blog = Contentment::Node::Blog
        ->retrieve($args{id} || $form->submission->results->{id});

    print $form->render({
        id          => $blog->id,
        title       => $blog->title,
        description => $blog->description,
        content     => $blog->content,
    });
}

else {
    # New
    $form->render;
}
