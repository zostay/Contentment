# vim: set ft=perl :

use strict;
use lib 'buildlib';

use Contentment;
use Contentment::Test;
use DateTime;
use Test::More tests => 54;

my $now = DateTime->now;

Contentment->configuration;

use_ok('Contentment::Security');
use_ok('Contentment::Security::DBI');
# 2
my $dbh = Contentment::Security::DBI::User->global_datasource_handle;
$dbh->do("DELETE FROM group_user");
$dbh->do("DELETE FROM user");
$dbh->do("DELETE FROM groups");
$dbh->do("DELETE FROM general_permission");

my $perm = Contentment::Security::Permission->new;
$perm->{class} = "Contentment::Security::DBI::User";
$perm->{scope} = 'w';
$perm->{capability_name} = 'create';
$perm->save({ skip_security => 1 });

$perm = Contentment::Security::Permission->new;
$perm->{class} = "Contentment::Security::DBI::Group";
$perm->{scope} = 'w';
$perm->{capability_name} = 'create';
$perm->save({ skip_security => 1 });

my $user = Contentment::Security::DBI::User->new;
$user->{username} = 'testme';
$user->{fullname} = 'Test A. Monkey';
$user->{email}    = 'test@contentment.org';
$user->{webpage}  = 'http://contentment.org/';
$user->{password} = 'testmepass';
ok($user->save);
# 3
ok($user->id);
is($user->{username}, 'testme');
is($user->{fullname}, 'Test A. Monkey');
is($user->{email}, 'test@contentment.org');
is($user->{webpage}, 'http://contentment.org/');
is($user->{password}, 'testmepass');
ok($user->{ctime} >= $now);
ok($user->{mtime} >= $now);
is($user->{dtime}, undef);
is($user->{lastlog}, undef);
is($user->{enabled}, 1);
is_deeply($user->{user_data}, {});
# 15
Contentment->security->check_login('testme', 'testmepass');

ok(Contentment->context->current_user);
is(Contentment->context->current_user->id, $user->id);
ok(Contentment->context->current_user->{lastlog} >= $now);
# 18
my $lookup_user = Contentment->security->fetch_user($user->id);
is($lookup_user->id, $user->id);
is($lookup_user->{username}, 'testme');
is($lookup_user->{fullname}, 'Test A. Monkey');
is($lookup_user->{email}, 'test@contentment.org');
is($lookup_user->{webpage}, 'http://contentment.org/');
is($lookup_user->{password}, 'testmepass');
isa_ok($lookup_user->{ctime}, 'DateTime');
ok($lookup_user->{ctime} >= $now);
isa_ok($lookup_user->{mtime}, 'DateTime');
ok($lookup_user->{mtime} >= $now);
is($lookup_user->{dtime}, undef);
ok($lookup_user->{lastlog} >= $now);
is($lookup_user->{enabled}, 1);
is_deeply($lookup_user->{user_data}, {});
# 32
$perm = Contentment::Security::Permission->new;
$perm->{class} = "Contentment::Security::DBI::User";
$perm->{object_id} = $user->id;
$perm->{scope} = 'u';
$perm->{scope_id} = $user->id;
$perm->{capability_name} = 'write';
$perm->save({ skip_security => 1 });

$user->{enabled} = 0;
ok($user->save);
# 33
ok($user->{dtime} >= $now);
# 34
my $group = Contentment::Security::DBI::Group->new;
$group->{groupname}   = 'testus';
$group->{description} = 'Test the Monkeys';
ok($group->save);
# 35
ok($group->add_user($user));
# 36
ok($group->id);
is($group->{groupname}, 'testus');
is($group->{description}, 'Test the Monkeys');
ok($group->{ctime} >= $now);
ok($group->{mtime} >= $now);
is($group->{dtime}, undef);
is($group->{enabled}, 1);
is_deeply($group->{group_data}, {});
# 44
$perm = Contentment::Security::Permission->new;
$perm->{class} = "Contentment::Security::DBI::Group";
$perm->{object_id} = $group->id;
$perm->{scope} = 'u';
$perm->{scope_id} = $user->id;
$perm->{capability_name} = 'write';
$perm->save({ skip_security => 1 });

my $lookup_group = Contentment->security->fetch_group($group->id);
is($lookup_group->id, $group->id);
is($lookup_group->{groupname}, 'testus');
is($lookup_group->{description}, 'Test the Monkeys');
ok($lookup_group->{ctime} >= $now);
ok($lookup_group->{mtime} >= $now);
is($lookup_group->{dtime}, undef);
is($lookup_group->{enabled}, 1);
is_deeply($lookup_group->{group_data}, {});
# 52
$group->{enabled} = 0;
ok($group->save);
# 53
ok($group->{dtime} >= $now);
# 54
