# vim: set ft=perl :

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use DateTime;
use Test::More tests => 53;

my $now = DateTime->now;

Contentment->configuration;

use_ok('Contentment::Security');
use_ok('Contentment::Security::DBI');
use_ok('Contentment::Content::Nodelet');

my $dbh = Contentment::Content::Nodelet->global_datasource_handle;
$dbh->do("DELETE FROM node");
$dbh->do("DELETE FROM revision");
$dbh->do("DELETE FROM user");
$dbh->do("DELETE FROM groups");
$dbh->do("DELETE FROM general_permission");

my $user = Contentment::Security::DBI::User->new;
$user->{username} = 'testme';
$user->{fullname} = 'Test A. Monkey';
$user->{email}    = 'test@contentment.org';
$user->{webpage}  = 'http://contentment.org/';
$user->{password} = 'testmepass';
ok($user->save({ skip_security => 1 }), "Insert user.");

my $group = Contentment::Security::DBI::Group->new;
$group->{groupname}   = 'testus';
$group->{description} = 'Test the Monkeys';
ok($group->save({ skip_security => 1 }), "Insert group.");

ok($group->user_add($user), "Add user to group.");

ok(Contentment->security->check_login('testme', 'testmepass'), "Check login.");

my $perm = Contentment::Security::Permission->new;
$perm->{class} = 'Contentment::Content::Testlet';
$perm->{scope} = 'u';
$perm->{scope_id} = $user->id;
$perm->{capability_name} = 'create';
ok($perm->save({ skip_security => 1 }), "Save nodelet create permission.");

my %spops = (
	testlet => {
		class				=> 'Contentment::Content::Testlet',
		isa					=> [ qw/ Contentment::Content::Nodelet / ],
		base_table			=> 'testlet',
		field				=> [ qw/
			testlet_id
			subject
			body
		/ ],
		id_field			=> 'testlet_id',
	},
);

SPOPS::Initialize->process({ config => \%spops });

Contentment::Content::Testlet->_create_table('MySQL', 'testlet', q(
	CREATE TABLE testlet (
		testlet_id			INT(11) NOT NULL,
		subject				VARCHAR(100) NOT NULL,
		body				TEXT NOT NULL,
		PRIMARY KEY (testlet_id));
));

$dbh->do("DELETE FROM testlet");

my $testlet = Contentment::Content::Testlet->new;
$testlet->{subject} = 'This is a test';
$testlet->{body} = "No really, this is a test!";
ok($testlet->save, "Insert nodelet.");

use Data::Dumper;
#diag(Dumper($dbh->selectall_arrayref("SELECT * FROM node")));
#diag(Dumper($dbh->selectall_arrayref("SELECT * FROM revision")));
#diag(Dumper($dbh->selectall_arrayref("SELECT * FROM testlet")));

$perm = Contentment::Security::Permission->new;
$perm->{class} = 'Contentment::Content::Testlet';
$perm->{scope} = 'u';
$perm->{scope_id} = $user->id;
$perm->{capability_name} = 'write';
$perm->save({ skip_security => 1 });

ok($testlet->id, "Nodelet id is set.");
is($testlet->{subject}, 'This is a test', $testlet->{subject});
is($testlet->{body}, 'No really, this is a test!', $testlet->{body});
ok(my $node = $testlet->node, "Nodelet has a node.");
ok($node->node_id, "Node has an id.");
is($node->id, $testlet->id, "Node id is nodelet id.");
is($node->module, 'Contentment::Content::Testlet', "Node module is Testlet.");
is($node->enabled, 1, "Node is enabled.");
ok($node->ctime >= $now, "Node ctime is set.");
is($node->creator->id, Contentment->context->current_user->id, "Node creator is set.");
ok($node->mtime >= $now, "Node mtime is set.");
is($node->updater->id, Contentment->context->current_user->id, "Node updater is set.");
is($node->dtime, undef, "Node dtime is not set.");
is($node->deleter, undef, "Node deleter is not set.");
ok(my $rev = $testlet->revision, "Nodelet has a revision.");
is($rev->id, $testlet->{testlet_id}, "Revision id is nodelet real id.");
is($rev->node_id, $node->id, "Revision node_id is node id.");
is($rev->version_number, 1, "Revision version number is 1.");
ok($rev->ctime >= $now, "Revision ctime is set.");
is($rev->creator->id, Contentment->context->current_user->id, "Revision creator is set.");
ok($rev->mtime >= $now, "Revision mtime is set.");
is($rev->updater->id, Contentment->context->current_user->id, "Revision updater is set.");
is($rev->dtime, undef, "Revision dtime is not set.");
is($rev->deleter, undef, "Revision deleter is not set.");

my $revision_id    = $testlet->revision->id;
my $version_number = $testlet->revision->version_number;

$testlet->{subject} = 'This is a better test';
ok($testlet->save({ create_revision => 1 }), "Create nodelet revision.");
isnt($testlet->revision->id, $revision_id, "Revision id has changed.");

#diag(Dumper($dbh->selectall_arrayref("SELECT * FROM node")));
#diag(Dumper($dbh->selectall_arrayref("SELECT * FROM revision")));
#diag(Dumper($dbh->selectall_arrayref("SELECT * FROM testlet")));

my $nodes = Contentment::Content::Node->fetch_group({ skip_security => 1 });
my $revs = Contentment::Content::Revision->fetch_group({ skip_security => 1 });

is(scalar(@$nodes), 1, "There is 1 node.");
is(scalar(@$revs), 2, "There are 2 revisions.");

is($testlet->revision->version_number, $version_number + 1, "Revision version number is $version_number + 1.");
is($testlet->subject, 'This is a better test', $testlet->subject);
is($testlet->body, 'No really, this is a test!', $testlet->body);

ok(my $old_testlet = Contentment::Content::Testlet->fetch(
	$testlet->id, { version_number => $version_number }
), "Fetch nodelet version $version_number.");

is($old_testlet->id, $testlet->id, "Nodelet id did not change with new revision.");
is($old_testlet->subject, 'This is a test', $old_testlet->subject);
is($old_testlet->body, 'No really, this is a test!', $old_testlet->body);

my $revisions = Contentment::Content::Testlet->fetch_group({
	all_revisions => 1,
	where         => 'node.node_id = ?',
	value         => [ $testlet->node->id ],
});

is(scalar(@$revisions), 2, "There are 2 revisions.");

my ($t1, $t2) = sort { $a->version_number <=> $b->version_number } @$revisions;

#print STDERR $t1->as_string,"\n";
#print STDERR $t2->as_string,"\n";

is($t1->id, $old_testlet->id, "First node id is old node id.");
is($t1->version_number, $old_testlet->version_number, "First revision version number is old revision version number.");
is($t1->subject, $old_testlet->subject, $t1->subject);
is($t1->body, $old_testlet->body, $t1->body);

is($t2->id, $testlet->id, "Second node id is new node id.");
is($t2->version_number, $testlet->version_number, "Second revision version number is new revision number.");
is($t2->subject, $testlet->subject, $t2->subject);
is($t2->body, $testlet->body, $t2->body);
