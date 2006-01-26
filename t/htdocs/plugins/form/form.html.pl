=begin meta
    title => 'Form Test'
    description => 'Simple test form.'
=end meta
=cut

my $form = Contentment::Form->define(
    name     => 't::test_form',
    enctype  => 'multipart/form-data',
    activate => 1,
    widgets  => [
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
        test4 => {
            name  => 'test4',
            class => 'TextArea',
        },
    ],
);

if ($form->submission->is_finished) {
    while (my ($key, $value) = each %{ $form->submission->results }) {
        print "$key: $value\n";
    }
}

else {
    $form->render({ test2 => 'test2' });
}
