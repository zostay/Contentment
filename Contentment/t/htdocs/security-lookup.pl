=begin meta
kind => 'text/plain'
=end meta
=cut

my $principal = Contentment::Security->lookup_principal('admin');

print "type = ",$principal->type,"\n";
print "username = ",$principal->username,"\n";
print "full_name = ",$principal->full_name,"\n";
