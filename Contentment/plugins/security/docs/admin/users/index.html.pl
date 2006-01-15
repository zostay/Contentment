=begin meta
    description => 'List of users for this web site.'
    title       => 'Users'
=end meta
=cut

Contentment::Security->check_permission(
    'Contentment::Security::Manager::manage_users');

print qq(<p><a href="admin/users/edit.html">New User</a></p>);

my @profiles = Contentment::Security::Profile::Persistent->search;
print qq(<table>\n);
print qq(<tr><th>Username</th><th>Full Name</th><th>Email Address</th><th>Web Site</th></tr>\n);
for my $profile (@profiles) {
    print q(<tr>);
    print q(<td><a href="admin/users/edit.html?id=).$profile->id.q(">).$profile->username.q(</a></td>);
    print q(<td>).$profile->full_name.q(</td>);
    
    if ($profile->email_address) {
        print q(<td><a href="mailto:).$profile->email_address.q(">).$profile->email_address.q(</a></td>);
    }
    else {
        print q(<td>-</td>);
    }

    if ($profile->web_site) {
        print q(<td><a target="_blank" href=").$profile->web_site.q(">).$profile->web_site.q(</a></td>);
    }
    else {
        print q(<td>-</td>);
    }

    print qq(</tr>\n);
}
print qq(</table>\n);
