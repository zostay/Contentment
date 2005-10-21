# vim: set ft=perl :

use strict;
use Test::More tests => 4;

SKIP: {
    eval "use Apache::TestRequest qw( GET_BODY POST_BODY )";
    skip "Apache::Test is not installed.", 1 if $@;

    Apache::TestRequest::user_agent(cookie_jar => {});

    my $body = GET_BODY('/form.html');

    like($body, qr{^Username: <input id="username" name="username" type="text" />}m);
    like($body, qr{^Password: <input id="password" name="password" type="password" />}m);

    $body = POST_BODY('/form.html', [
        _submitted => 1,
        username   => 'foo',
        password   => 'bar',
        _submit    => 'Submit',
    ]);

    like($body, qr{^Username: foo}m);
    like($body, qr{^Password: bar}m);
}
