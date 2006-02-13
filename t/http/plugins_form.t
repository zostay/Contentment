# vim: set ft=perl :

use strict;
use Contentment::Test;
use Test::More tests => 11;

my $s = 1;

my $body = parse_html(my $content = GET('/plugins/form/form.html')->content);

$s &= has_tag_with_attrs($body, 'form', {
    enctype => 'multipart/form-data',
    method  => 'POST',
}, 'form');

$s &= has_tag_with_attrs($body, 'input', {
    type  => 'hidden',
    name  => 'FORM',
    value => 't::test_form',
}, 'FORM');

my $has_submission_id = 
$s &= has_tag_with_attrs($body, 'input', {
    type  => 'hidden',
    name  => 'ID',
    value => qr|^ [0-9A-F]{8}- (?:[0-9A-F]{4}-){3} [0-9A-F]{12} $|x,
}, 'ID');

$s &= has_tag_with_attrs($body, 'input', {
    type  => 'hidden',
    name  => 'ACTIVATE',
    value => 1,
}, 'ACTIVATE');

$s &= has_tag_with_attrs($body, 'label', { for => 'test1' }, 'label');

$s &= has_tag_with_attrs($body, 'input', {
    type => 'text',
    name => 'test1',
    id   => 'test1',
}, 'Text');

$s &= has_tag_with_attrs($body, 'input', {
    type  => 'submit',
    name  => 'test3',
    id    => 'test3',
    value => 'test3',
}, 'Submit');

$s &= has_tag_with_attrs($body, 'textarea', {
    name  => 'test4',
    id    => 'test4',
}, 'TextArea');

SKIP: {
    skip "No submission ID, cannot test form POSTs.", 3 
        if !$has_submission_id;

    my $toke = HTML::TokeParser->new(\$content);

    my $submission_id;
    TAG:
    while (my $tag = $toke->get_tag('input')) {
        if ($tag->[1]{name} eq 'ID') {
            $submission_id = $tag->[1]{value};
            last TAG;
        }
    }

    diag($content) if !$s;

    #    diag("Using submission_id = $submission_id");

    $content = POST('/plugins/form/form.html', [
        FORM         => 't::test_form',
        ID           => $submission_id,
        ACTIVATE     => 1,
        test1        => 'test1',
        test3        => 'test3',
    ])->content;

    for my $i (1 .. 3) {
        $s &= like($content, qr{^test$i: test$i}m);
    }
}

diag($content) if !$s;
