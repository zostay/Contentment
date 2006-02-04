# vim: set = perl :

use strict;
use Test::More tests => 13;
use Contentment::Hooks;

eval {
	Contentment::Hooks->register;
};
ok($@, 'no hook argument');

eval {
	Contentment::Hooks->register(
		hook => 'test',
	);
};
ok($@, 'no code argument');

Contentment::Hooks->register(
	hook => 'test',
	code => sub { ok(1, shift) },
);
Contentment::Hooks->call('register/call ran');

Contentment::Hooks->register(
	hook => 'test2',
	code => sub {},
	id   => 'test2',
);
is(Contentment::Hooks->count('test2'), 1);

eval {
	Contentment::Hooks->register(
		hook => 'test2',
		code => sub{},
		id   => 'test2',
	);
};
ok($@, 'same id used twice');
is(Contentment::Hooks->count('test2'), 1);

Contentment::Hooks->unregister('test2', 'test2');
is(Contentment::Hooks->count('test2'), 0);

Contentment::Hooks->register(
	hook => 'test3',
	code => sub { ok(1, 'test3 name1'); },
	name => 'name1',
);

Contentment::Hooks->register(
	hook => 'test3',
	code => sub { ok(1, 'test3 name2'); },
	name => 'name2',
);

is(Contentment::Hooks->count('test3'), 2);
is(Contentment::Hooks->count_named('test3', 'name1'), 1);
is(Contentment::Hooks->count_named('test3', 'name2'), 1);

Contentment::Hooks->call('test3');
Contentment::Hooks->call_named('test3', 'name1');
Contentment::Hooks->call_named('test3', 'name2');
