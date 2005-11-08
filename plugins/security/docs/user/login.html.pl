=begin meta
    title       => 'Login'
    description => 'Login to the web site.'
=end meta
=cut

my $template = <<'END_OF_TEMPLATE';
[% form.begin %]

[% SET errors = form.submission.errors %]

[% IF errors.FORM %]
<p class="error">[% errors.FORM %]</p>
[% END %]

[% form.widgets.username.label.render %]
[% form.widgets.username.render %]
[% IF errors.username %]
<span class="error">[% errors.username %]</span>
[% END %]
<br/>

[% form.widgets.password.label.render %]
[% form.widgets.password.render %]
[% IF errors.password %]
<span class="error">[% errors.password %]</span>
[% END %]
<br/>

[% form.widgets.submit.render %]
[% form.end %]
END_OF_TEMPLATE

my $form = Contentment::Form->define({
    name      => 'Contentment::Security::Manager::login_form',
    method    => 'POST',
    action    => 'Contentment::Security::Manager::process_login_form',
    activate  => 1,
    template  => \$template,
    widgets   => {
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
    },
});

if ($form->submission->is_finished) {
    Contentment::Response->redirect('index.html')->generate;
}

else {
    print $form->render;
}
