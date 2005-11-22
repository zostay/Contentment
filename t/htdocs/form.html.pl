=begin meta
    title => 'Form Test'
    description => 'Simple test form.'
=end meta
=cut

my $template = <<'END_OF_TEMPLATE';
<form>
</form>
[% USE Form -%]
[% Form.begin %]
[% Form.widgets.test1.label.render %] [% Form.widgets.test1.render %]<br/>
[% Form.widgets.test3.render %]
[% Form.end %]

END_OF_TEMPLATE

my $form = Contentment::Form->define(
    name     => 't::test_form',
    enctype  => 'multipart/form-data',
    activate => 1,
#    template => [ 'Template', {
#        source => $template,
#    }, ],
    widgets  => {
        test1 => {
            name  => 'test1',
            class => 'Text',
        },
        test2 => {
            name  => 'test2',
            class => 'Hidden',
        },
        test3 => {
            name  => 'test3',
            class => 'Submit',
            value => 'test3',
        },
    },
);

if ($form->submission->is_finished) {
    while (my ($key, $value) = each %{ $form->submission->results }) {
        print "$key: $value\n";
    }
}

else {
    $form->render({ test2 => 'test2' });
}
