# vim: set ft=perl :

use strict;
use Contentment;
use File::System::Test;
use Test::More tests => 212;

close STDERR;
open STDERR, '>>t/logs/error_log' 
    or die "Failed to append to error_log: $!";

chdir "t/htdocs/cgi-bin";

my @dirs = qw(
    cgi-bin themes themes/default themes/default/style themes/default/text
    themes/default/text/html test plugins plugins/form plugins/index
    plugins/node plugins/perl plugins/security plugins/session plugins/settings
    plugins/template plugins/theme plugins/vfs
);

my @files = qw(
    plugins/vfs/foo.txt plugins/form/form.html.pl generator.pl index.html 
    plugins/node/node.pl plugins/perl/perl.pl plugins/perl/pod.pod 
    plugins/security/security-lookup.pl plugins/security/security.pl 
    plugins/session/session1.pl plugins/session/session2.pl
    plugins/settings/settings.pl plugins/template/template.tt2 
    plugins/theme/theme.pl themes/default/style/main.css
    themes/default/text/html/toc-hier.pl themes/default/text/html/toc.pl
    themes/default/text/html/top.tt2 test/Testing_2 test/Testing_3
);

Contentment->begin;
my $root = Contentment::VFS->instance;

# Checking initial file system root
is_root_sane($root);

# Check for some files that they exist and are sane
for my $path (@dirs, @files) {
    ok($root->exists($path));
    is_object_sane($root->lookup($path));
}

ok(defined $root->child('plugins'));
ok(!defined $root->child('plugins2'));

for my $path (@dirs, @files) {
    my $obj = $root->lookup($path);

    is_object_sane($obj);

    # properties
    my @properties = $obj->properties;
    cmp_ok(scalar(@properties), '>=', 4);
}

for my $path (@files) {
    my $obj = $root->lookup($path);

    is_content_sane($obj);
}

for my $path (@dirs) {
    my $obj = $root->lookup($path);

    is_container_sane($obj);
}

is_glob_and_find_consistent($root);

for my $path (@dirs) {
    my $obj = $root->lookup($path);

    is_glob_and_find_consistent($obj);
}

Contentment->end;
