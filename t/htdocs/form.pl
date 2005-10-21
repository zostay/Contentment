=begin meta
kind => 'text/html'
=end meta
=cut

my $form = Contentment::Form->new_form(
	fields   => [ qw( username password ) ],
	method   => 'POST',
	validate => {
		username => '/[a-z][a-z0-9]{1,7}/',
	},
	required => 'ALL',
    template => '/form-template.tt2',
);

$form->field(name => 'password', type => 'password');

if ($form->submitted && $form->validate) {
    my $fields = $form->fields;
    print "Username: $fields->{username}<br/>\n";
    print "Password: $fields->{password}<br/>\n";
} else {
	print $form->render;
}
