=begin meta
    description => 'List of roles for this web site.'
    title       => 'Roles'
=end meta
=cut

$context->security->check_permission(
    'Contentment::Security::Manager::manage_roles');

print qq(<p><a href="admin/roles/edit.html">New Role</a></p>);

my @roles = Contentment::Security::Role->search;
print qq(<table>\n);
print qq(<tr><th>Role</th><th>Description</th><th>Special</th></tr>\n);
for my $role (@roles) {
    print q(<tr>);
    print q(<td><a href="admin/roles/edit.html?id=).$role->id.q(">).$role->title.q(</a></td>);
    print q(<td>).$role->description.q(</td>);
    print q(<td>).($role->is_special?'Yes':'No').q(</td>);
    print qq(</tr>\n);
}
print qq(</table>\n);
