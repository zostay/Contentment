my $index = $context->catalog->index('Contentment::Test::Index');

for my $term ($index->search('A', 'I', 'F')) {
    print " - ",$term->title,"\n"; 

    my @generators = $term->generators;
    for my $generator (@generators) {
        print "    - ", $generator->get_property('path'),"\n";
    }
}
