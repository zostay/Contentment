# vim: set ft=perl :

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use DateTime;
#use Test::More tests => 33;
use Test::More skip_all => "Node API is not finished.";

Contentment->configuration;

require Contentment::Security;

use_ok('Contentment::Content::Node');
use_ok('Contentment::Security::DBI');
# 2
# Make sure the test database is clean:
my $dbh = Contentment::Content::Node->global_datasource_handle;
$dbh->do("DELETE FROM node");
$dbh->do("DELETE FROM user");
$dbh->do("DELETE FROM groups");

my $user = Contentment::Security::DBI::User->new;
$user->{username} = 'testme';
$user->{fullname} = 'Test A. Monkey';
$user->{email}    = 'test@contentment.org';
$user->{webpage}  = 'http://contentment.org/';
$user->{password} = 'testmepass';
ok($user->save({ skip_security => 1 }));
# 3
my $group = Contentment::Security::DBI::Group->new;
$group->{groupname}   = 'testus';
$group->{description} = 'Test the Monkeys';
ok($group->save({ skip_security => 1 }));
# 4
ok($group->user_add($user));
# 5
ok(Contentment->security->check_login('testme', 'testmepass'));
# 6

my $perm = Contentment::Security::Permission->new;
$perm->{class} = 'Contentment::Content::Test';
$perm->{scope} = 'u';
$perm->{scope_id} = $user->id;
$perm->{capability_name} = 'create';
$perm->save;

$perm = Contentment::Security::Permission->new;
$perm->{class} = 'Contentment::Content::Test';
$perm->{scope} = 'u';
$perm->{scope_id} = $user->id;
$perm->{capability_name} = 'write';
$perm->save;

{
	package Contentment::Content::Test;

	my %spops = (
		test => {
			class => 'Contentment::Content::Test',
			isa   => [ qw/ Contentment::SPOPS / ],
			base_table => 'test_table',
			field      => [ qw/
				node_rev_id
				subject
				body_text
			/ ],
			id_field   => 'node_rev_id',
		},
	);

	SPOPS::Initialize->process({ config => \%spops });

	__PACKAGE__->_create_table('MySQL', 'test_table', q(
		CREATE TABLE test_table (
			node_rev_id			INT(11) NOT NULL,
			subject				VARCHAR(100) NOT NULL,
			body_text			TEXT NOT NULL,
			PRIMARY KEY (node_rev_id));
	));
}

my $now = DateTime->now;

my $node = Contentment::Content::Node->new;
$node->{module} = 'Contentment::Content::Test';
$node->{path} = '/test/foo';
$node->{enabled} = 1;
$node->{node_owner} = Contentment->context->current_user->id;
$node->{node_group} = Contentment->context->current_user->group->[0]->id;
ok($node->save);
# 7
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
# 21
my $revision = $node->revision;
is($revision->revision_id, 1);
is($revision->node_id, $node->id);
ok($revision->ctime >= $now);
is($revision->creator, Contentment->context->current_user->id);
ok($revision->mtime >= $now);
is($revision->updater, Contentment->context->current_user->id);
is($revision->dtime, undef);
is($revision->deleter, undef);
# 29
$now = DateTime->now;

$dbh->begin_work;
$revision->touch;
$dbh->commit;

ok($node->ctime >= $now);
ok($node->mtime >= $now);
ok($revision->ctime >= $now);
ok($revision->mtime >= $now);
# 33
