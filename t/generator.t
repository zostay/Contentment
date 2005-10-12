# vim: set ft=perl :

use strict;
use Contentment::Generator;
use Test::More tests => 11;

my $generator;
ok($generator = Contentment::Generator->new, 'new');

is($generator->generated_kind, '', 'default generated kind');
is($generator->generated_kind(foo => 1), '', 'default generated kind with args');

$generator->set_generated_kind(sub { 'test'.join(',',@_) });
is($generator->generated_kind, 'test', 'set genereted kind');
is($generator->generated_kind(foo => 1), 'testfoo,1', 'set generated kind with args');

is($generator->set_property(foo => 1), 1, 'set_property');
is($generator->set_property(bar => 'baz'), 'baz', 'set_property');
is($generator->get_property('foo'), 1, 'get_property');
is($generator->get_property('bar'), 'baz', 'get_property');

$generator->set_generator(sub { 'test'.join(',',@_) });
is($generator->generate, 'test', 'generator');
is($generator->generate(bar => 'baz'), 'testbar,baz', 'generator');
