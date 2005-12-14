=begin meta
    title       => 'Login'
    description => 'Login to the web site.'
=end meta
=cut

my $form = Contentment::Form->define({
    name      => 'Contentment::Security::Manager::login_form',
    action    => 'Contentment::Security::Manager::process_login_form',
    activate  => 1,
    widgets   => [
        username => {
            name  => 'username',
            class => 'Text',
        },
        password => {
            name  => 'password',
            class => 'Text',
            type  => 'password',
        },
        submit => {
            value => 'Login',
            class => 'Submit',
        },
    ],
});

if ($form->submission->is_finished) {
    Contentment::Response->redirect('index.html')->generate;
}

else {
    print $form->render;
}
