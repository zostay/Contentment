# vim: set ft=perl :

use strict;
use Test::More tests => 6;
use Contentment::Hooks;
use Contentment::Log;

can_ok('Contentment::Log', qw/ log debug info warning error /);

Contentment::Hooks->register(
	hook => 'Contentment::Log::error',
	code => sub { my $msg = shift; is($msg->{message}, '1', $msg->{level}) },
);

Contentment::Log->log({
	name    => 'error',
	message => '%d',
	args    => [ 1 ],
	level   => 'CUSTOM',
}) || ok(0, 'CUSTOM');

Contentment::Log->debug('%d', [1])   || ok(0, 'DEBUG');
Contentment::Log->info('%d', [1])    || ok(0, 'INFO');
Contentment::Log->warning('%d', [1]) || ok(0, 'WARNING');
Contentment::Log->error('%d', [1])   || ok(0, 'ERROR');
