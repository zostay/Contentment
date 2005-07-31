# vim: set ft=perl :

use strict;
use lib 'buildlib';

use Contentment;
use Contentment::Test;
use Test::More tests => 15;

my $context = Contentment->context;
ok($context);
is($context->url, undef);
is($context->m, undef);
is($context->r, undef);
ok($context->vfs);
ok($context->setting);

is($context->original_kind, 'text/html');

ok($context->panel);
is($context->panel->url, undef);
is($context->panel->name, '__DEFAULT__');
is($context->panel->map, 'Contentment::Context::error_map');

is_deeply($context->panels, []);

is($context->submission, undef);

is_deeply($context->submissions, []);

is_deeply($context->last_processed, []);
