my $generator = Contentment::Generator->generator('Plain', {
    source     => sub { print 'test',join(',',@_),"\n" },
    properties => {
        foo  => 1,
        bar  => 'baz',
        kind => 'test',
    },
});

print "GENERATOR IS\n" if $generator;

print "kind = ",$generator->get_property('kind'),"\n";
print "foo = ",$generator->get_property('foo'),"\n";
print "bar = ",$generator->get_property('bar'),"\n";

print "BEGIN PLAIN\n";
$generator->generate;
print "END\n";

print "BEGIN ARGS\n";
$generator->generate(bar => 'baz');
print "END\n";
