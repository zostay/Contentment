package Contentment::Template::Document;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Template::Document';

our $AUTOLOAD;
sub AUTOLOAD {
	my $self = shift;
	my $method = $AUTOLOAD;

	$method =~ s/.*:://;
	return if $method eq 'DESTROY';
	return $self->{GENERATOR}->get_property($method);
}

1
