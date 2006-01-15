use Contentment::Setting;

my $settings = Contentment::Setting->instance;

$settings->{testing_foo} = 'foo';
$settings->{testing_bar} = 2;
$settings->{testing_baz} = [ qw/ foo bar baz qux / ];
$settings->{testing_qux} = { foo => 1, bar => 2 };

print "testing_foo = $settings->{testing_foo}\n";
print "testing_bar = $settings->{testing_bar}\n";
print "testing_baz refs a ",ref($settings->{testing_baz}),"\n";
print "testing_qux refs a ",ref($settings->{testing_qux}),"\n";
print "testing_baz[0] = $settings->{testing_baz}[0]\n";
print "testing_baz[1] = $settings->{testing_baz}[1]\n";
print "testing_baz[2] = $settings->{testing_baz}[2]\n";
print "testing_baz[3] = $settings->{testing_baz}[3]\n";
print "testing_qux{foo} = $settings->{testing_qux}{foo}\n";
print "testing_qux{bar} = $settings->{testing_qux}{bar}\n";
