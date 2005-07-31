# vim: set ft=perl :

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use DateTime;
#use Test::More tests => 30;
use Test::More skip_all => "Node API is not finished.";

Contentment->configuration;

use_ok('Contentment::Content::Node');
use_ok('Contentment::Security::DBI');

# Make sure the test database is clean:
my $dbh = Contentment::Content::Node->global_datasource_handle;
$dbh->do("DELETE FROM node");
$dbh->do("DELETE FROM user");

my $user = Contentment::Security::DBI::User->new;
$user->{username} = 'testme';
$user->{fullname} = 'Test A. Monkey';
$user->{email}    = 'test@contentment.org';
$user->{webpage}  = 'http://contentment.org/';
$user->{password} = 'testmepass';
ok($user->save);

Contentment->security->check_login('testme', 'testmepass');

my $now = DateTime->now;

my $node = Contentment::Content::Node->new;
$node->{module} = 'Contentment::Content::Test';
$node->{path} = '/test/foo';
$node->{enabled} = 1;
$node->{node_owner} = Contentment->context->current_user->id;
$node->{node_group} = Contentment->context->current_user->group->[0]->id;
ok(eval { $node->save });
ok(!$@);

ok($node->node_id >= 1);
is($node->head_node_rev_id, 1);
is($node->module, 'Contentment::Content::Test');
is($node->path, '/test/foo');
ok($node->enabled);
is($node->owner, Contentment->context->current_user->id);
is($node->group, Contentment->context->current_user->group->[0]->id);
ok($node->ctime >= $now);
is($node->creator, Contentment->context->current_user->id);
ok($node->mtime >= $now);
is($node->updater, Contentment->context->current_user->id);
is($node->dtime, undef);
is($node->deleter, undef);

my $revision = $node->revision;
is($revision->revision_id, 1);
is($revision->node_id, $node->id);
ok($revision->ctime >= $now);
is($revision->creator, Contentment->context->current_user->id);
ok($revision->mtime >= $now);
is($revision->updater, Contentment->context->current_user->id);
is($revision->dtime, undef);
is($revision->deleter, undef);

$now = DateTime->now;

$dbh->begin_work;
$revision->touch;
$dbh->commit;

ok($node->ctime >= $now);
ok($node->mtime >= $now);
ok($revision->ctime >= $now);
ok($revision->mtime >= $now);

