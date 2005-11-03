# vim: set ft=perl :

use strict;
use Test::More tests => 10;

SKIP: {
    eval "use Apache::TestRequest qw( GET_BODY POST_BODY )";
    skip "Apache::Test is not installed.", 10 if $@;

    eval "use HTML::TokeParser";
    skip "HTML::TokeParser is not installed.", 10 if $@;

    eval "require 't/html_test.pl'";
    skip qq(Failed to load helper library "t/html_test.pl": $@), 10 if $@;

    Apache::TestRequest::user_agent(cookie_jar => {});

    my $body = parse_html(my $content = GET_BODY('/form.html'));

    has_tag_with_attrs($body, 'form', {
        enctype => 'multipart/form-data',
        method  => 'POST',
    }, 'form');

    has_tag_with_attrs($body, 'input', {
        type  => 'hidden',
        name  => '__form__',
        value => 't::test_form',
    }, '__form__');

    my $has_submission_id = 
    has_tag_with_attrs($body, 'input', {
        type  => 'hidden',
        name  => '__id__',
        value => qr|^ [0-9A-F]{8}- (?:[0-9A-F]{4}-){3} [0-9A-F]{12} $|x,
    }, '__id__');

    has_tag_with_attrs($body, 'input', {
        type  => 'hidden',
        name  => '__activate__',
        value => 1,
    }, '__activate__');

    has_tag_with_attrs($body, 'label', { for => 'test1' }, 'label');

    has_tag_with_attrs($body, 'input', {
        type => 'text',
        name => 'test1',
        id   => 'test1',
    }, 'Text');

    has_tag_with_attrs($body, 'input', {
        type  => 'submit',
        name  => 'test3',
        id    => 'test3',
        value => 'test3',
    }, 'Submit');

    skip "No submission ID, cannot test form POSTs.", 3 
        if !$has_submission_id;

    my $toke = HTML::TokeParser->new(\$content);
    
    my $submission_id;
    TAG:
    while (my $tag = $toke->get_tag('input')) {
        if ($tag->[1]{name} eq '__id__') {
            $submission_id = $tag->[1]{value};
            last TAG;
        }
    }

#    diag("Using submission_id = $submission_id");

    $content = POST_BODY('/form.html', [
        __form__     => 't::test_form',
        __id__       => $submission_id,
        __activate__ => 1,
        test1        => 'test1',
        test3        => 'test3',
    ]);

    for my $i (1 .. 3) {
        like($content, qr{^test$i: test$i}m);
    }
}
