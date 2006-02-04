# vim: set ft=perl :

use strict;
use Test::More tests => 41;

SKIP: {
    eval "use Apache::TestRequest 'GET_BODY'";
    skip "Apache::Test is not installed.", 41 if $@;

    Apache::TestRequest::user_agent(cookie_jar => {});

    my $body = GET_BODY('/plugins/security/security.txt');

    like($body, qr{^type = anonymous}m);
    like($body, qr{^username = Anonymous}m);
    like($body, qr{^full_name = }m);
    like($body, qr{^email_address = }m);
    like($body, qr{^web_site = }m);
    like($body, qr{^roles = Anonymous Everybody}m);
    like($body, qr{^permissions = }m);
    like($body, qr{^information\.foo = 1}m);
    like($body, qr{^preferences\.bar = 1}m);

    $body = GET_BODY('/plugins/security/security.txt');

    like($body, qr{^type = authenticated}m);
    like($body, qr{^username = admin}m);
    like($body, qr{^full_name = Site Administrator}m);
    like($body, qr{^email_address = }m);
    like($body, qr{^web_site = }m);
    like($body, qr{^roles = SuperUser Authenticated Everybody}m);
    like($body, qr{^permissions = SuperUser}m);
    like($body, my $auth_re_foo = qr{^information\.foo = (\d+)}m);
    my ($auth_foo) = $body =~ $auth_re_foo;
    ok($auth_foo++ >= 1);
    like($body, my $auth_re_bar = qr{^preferences\.bar = (\d+)}m);
    my ($auth_bar) = $body =~ $auth_re_bar;
    ok($auth_bar++ >= 1);

    $body = GET_BODY('/plugins/security/security.txt');

    like($body, qr{^type = anonymous}m);
    like($body, qr{^username = Anonymous}m);
    like($body, qr{^full_name = Test A\. Monkey}m);
    like($body, qr{^email_address = test\.a\.monkey\@cpan\.org}m);
    like($body, qr{^web_site = http://search.cpan.org/}m);
    like($body, qr{^roles = Anonymous Everybody}m);
    like($body, qr{^permissions = }m);
    like($body, qr{^information\.foo = 1}m);
    like($body, qr{^preferences\.bar = 1}m);
    
    $body = GET_BODY('/plugins/security/security.txt');

    like($body, qr{^type = authenticated}m);
    like($body, qr{^username = admin}m);
    like($body, qr{^full_name = Site Administrator}m);
    like($body, qr{^email_address = }m);
    like($body, qr{^web_site = }m);
    like($body, qr{^roles = SuperUser Authenticated Everybody}m);
    like($body, qr{^permissions = SuperUser}m);
    like($body, qr{^information\.foo = $auth_foo}m);
    like($body, qr{^preferences\.bar = $auth_bar}m);

    $body = GET_BODY('/plugins/security/security-lookup.txt');

    like($body, qr{^type = authenticated}m);
    like($body, qr{^username = admin}m);
    like($body, qr{^full_name = Site Administrator}m);
}
