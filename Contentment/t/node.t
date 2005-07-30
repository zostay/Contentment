# vim: set ft=perl :

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use DateTime;
#use Test::More tests => 27;
use Test::More skip_all => "Node API is not finished.";

Contentment->configuration;

use_ok('Contentment::Content::Node');

# Make sure the test database is clean:
my $dbh = Contentment::Content::Node->global_datasource_handle;
$dbh->do("DELETE FROM node");

my $now = DateTime->now;

my $node = Contentment::Content::Node->new;
$node->{module} = 'Contentment::Content::Test';
$node->{path} = '/test/foo';
$node->{enabled} = 1;
$node->{node_owner} = $Contentment::context->current_user->id;
$node->{node_group} = $Contentment::context->current_user->group->[0]->id;
eval { $node->save };
ok(!$@);

ok($node->node_id >= 1);
is($node->head_node_rev_id, 1);
is($node->module, 'Contentment::Content::Test');
is($node->path, '/test/foo');
ok($node->enabled);
is($node->owner, $Contentment::context->current_user->id);
is($node->group, $Contentment::context->current_user->group->[0]->id);
ok($node->ctime > $now);
is($node->creator, $Contentment::context->current_user->id);
ok($node->mtime > $now);
is($node->updater, $Contentment::context->current_user->id);
ok(!defined($node->dtime));
ok(!defined($node->deleter));

my $revision = $node->revision;
is($revision->revision_id, 1);
is($revision->node_id, $node->id);
ok($revision->ctime > $now);
is($revision->creator, $Contentment::context->current_user->id);
ok($revision->mtime > $now);
is($revision->updater, $Contentment::context->current_user->id);
ok(!defined($revision->dtime));
ok(!defined($revision->deleter));

$now = DateTime->now;

$dbh->begin_work;
$revision->touch;
$dbh->commit;

ok($node->ctime > $now);
ok($node->mtime > $now);
ok($revision->ctime > $now);
ok($revision->mtime > $now);

