# vim: set ft=perl :

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use DateTime;
#use Test::More tests => 17;
use Test::More skip_all => "Nodelet API is not finished.";

use_ok('Contentment::Content::Nodelet');

my %spops = (
	testlet => {
		class				=> 'Contentment::Content::Testlet',
		isa					=> [ qw/ Contentment::Content::Nodelet / ],
		base_table			=> 'testlet',
		field				=> [ qw/
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

my $testlet = Contentment::Content::Testlet->new;
$testlet->{subject} = 'This is a test';
$testlet->{body} = "No really, this is a test!";
eval { $testlet->save };
ok(!$@);

my $revision_id = $testlet->revision_id;

$testlet->{subject} = 'This is a better test';
eval { $testlet->save( create_revision => 1 ) };
ok(!$@);

is($testlet->revision_id, $revision_id + 1);
is($testlet->subject, 'This is a better test');
is($testlet->body, 'No really, this is a test!');

my $old_testlet = Contentment::Content::Testlet->fetch(
	$testlet->node_id, revision_id => $revision_id
);

is($old_testlet->node_id, $testlet->node_id);
is($old_testlet->subject, 'This is a test');
is($old_testlet->body, 'No really, this is a test!');

my $revisions = Contentment::Content::Testlet->fetch_group(
	all_revisions => 1,
	where => 'node.node_id = ?',
	value => [ $testlet->node_id ],
);

my ($t1, $t2) = sort { $a->revision_id <=> $b->revision_id } @$revisions;

is($t1->node_id, $old_testlet->node_id);
is($t1->revision_id, $old_testlet->revision_id);
is($t1->subject, $old_testlet->subject);
is($t1->body, $old_testlet->body);

is($t2->node_id, $testlet->node_id);
is($t2->revision_id, $testlet->revision_id);
is($t2->subject, $testlet->subject);
is($t2->body, $testlet->body);
