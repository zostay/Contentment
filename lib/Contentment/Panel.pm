package Contentment::Panel;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Class::Accessor';

__PACKAGE__->mk_ro_accessors(qw/ url name map /);

sub new {
	my ($class, $url, $name, $map) = @_;

	return $class->SUPER::new({
		url  => $url,
		name => $name,
		map  => $map,
	});
}

1
