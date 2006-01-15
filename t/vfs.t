# vim: set ft=perl :

use strict;
use Contentment;
use File::System::Test;
use Test::More tests => 151;

close STDERR;
open STDERR, '>>t/logs/error_log' 
    or die "Failed to append to error_log: $!";

chdir "t/htdocs/cgi-bin";

my @dirs = qw(
    cgi-bin themes themes/default themes/default/style
    themes/default/text themes/default/text/html test
);

my @files = qw(
    foo.txt form-template.tt2 form.html.pl generator.pl index.html node.pl
    perl.pl pod.pod security-lookup.pl security.pl session1.pl session2.pl
    settings.pl template.tt2 theme.pl themes/default/style/main.css
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

ok(defined $root->child('foo.txt'));
ok(!defined $root->child('foo2.txt'));

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
