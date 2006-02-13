=begin meta
kind => 'text/plain'
=end meta
=cut

my $principal = $context->security->lookup_principal('admin');

print "type = ",eval { $principal->type },"\n";
print "username = ",eval { $principal->username },"\n";
print "full_name = ",eval { $principal->full_name },"\n";
