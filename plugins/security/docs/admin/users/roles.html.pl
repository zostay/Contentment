my %args = @_;
my $profile = $args{profile};



print qq(<h2>Roles</h2>\n);
print qq(<table>\n);
print qq(<tr><th>Role</th><th>Description</th><th>Action</th></tr>\n);
for my $role (@{ $profile->roles }) {
    my $uid = $profile->id;
    my $rid = $role->id;

    print q(<tr>);
    print q(<td>).$role->title.q(</td>);
    print q(<td>).$role->description.q(</td>);
    print qq(<td><a href="admin/users/remove-role?uid=$uid&pid=$rid">Revoke</a></td>);
    print qq(</tr>\n);
}
print qq(</table>\n);
