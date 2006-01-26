=begin meta
kind => 'text/plain'
=end meta
=cut

my $principal = Contentment::Security->get_principal;

$principal->information->{foo}++;
$principal->preferences->{bar}++;

print "type = ",$principal->type,"\n";
print "username = ",$principal->username,"\n";
print "full_name = ",$principal->full_name,"\n";
print "email_address = ",$principal->email_address,"\n";
print "web_site = ",$principal->web_site,"\n";
print "roles = ",join(q{ }, map { $_->title } @{ $principal->roles }),"\n";
print "permissions = ",join(q{ }, keys %{ $principal->permissions }),"\n";
print "information.foo = ",$principal->information->{foo},"\n";
print "preferences.bar = ",$principal->preferences->{bar},"\n";

if ($principal->type eq 'anonymous') {
    $principal->profile->full_name('Test A. Monkey');
    $principal->profile->email_address('test.a.monkey@cpan.org');
    $principal->profile->web_site('http://search.cpan.org/');

    Contentment::Security->security_manager->login('admin', 'secret');
}
else {
    Contentment::Security->security_manager->logout;
}
