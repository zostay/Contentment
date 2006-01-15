=begin meta
    title => 'Node Test'
    description => 'Test of the Node API.'
    kind => 'text/plain'
=end meta
=cut

my $node1 = Contentment::Node::Test->create({
    comment => 'Test 1',
    title   => 'Testing 1',
    content => 'This is a test.',
});
$node1->commit;

print 'node1 comment = ',$node1->comment,"\n";
print 'node1 title = ',$node1->title,"\n";
print 'node1 content = ',$node1->content,"\n";

my $node2 = Contentment::Node::Test->create({
    comment => 'Test 2',
    title   => 'Testing 2',
    content => 'This is another test.',
});
$node2->commit;

print 'node2 comment = ',$node2->comment,"\n";
print 'node2 title = ',$node2->title,"\n";
print 'node2 content = ',$node2->content,"\n";

$node1 = $node1->revise({
    comment => 'Test 3',
    title   => 'Testing 3',
    content => 'This is yet another test.',
});
$node1->commit;

#use Data::Dumper;
#print STDERR Dumper($node1);

print 'node1 comment = ',$node1->comment,"\n";
print 'node1 title = ',$node1->title,"\n";
print 'node1 content = ',$node1->content,"\n";

my @revisions = @{ $node1->revisions };

for my $index (0 .. $#revisions) {
    my $revision = Contentment::Node::Test->retrieve($revisions[$index]->id);

    print "revision[$index] comment = ",$revision->comment,"\n";
    print "revision[$index] title = ",$revision->title,"\n";
    print "revision[$index] content = ",$revision->content,"\n";
}
