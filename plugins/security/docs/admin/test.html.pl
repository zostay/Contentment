my $form = Contentment::Form->new_form(
    fields => [ 'option' ],
    values => {
        option => [ 'one', 'three' ],
    }
);

$form->field(
    name => 'option',
    multiple => 1,
    options => [ 'one', 'two', 'three', 'four' ],
);

print $form->render;
#print $form->render($form->submitted ? (sticky => 1) : ());
