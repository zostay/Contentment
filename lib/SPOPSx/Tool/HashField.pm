package SPOPSx::Tool::HashField;

use strict;
use warnings;

our $VERSION = '0.01';

use YAML qw(Load Dump);

# As far as I can tell from the docs, this is a violation of the guidelines for
# building rulesets. However, this is pretty much the same thing that
# SPOPS::Tool::DateConvert does!
sub ruleset_factory {
	my ($class, $rstab) = @_;
	push @{ $rstab->{post_fetch_action} }, \&convert_to_hash;
	push @{ $rstab->{pre_save_action} }, \&convert_to_string;
	push @{ $rstab->{post_save_action} }, \&convert_to_hash;
	return __PACKAGE__
}

# TODO Add a thingy to walk the created data structure and attempt to require
# any packages objects have been blessed into.
sub convert_to_hash {
	my $self = shift;
	my @hash_fields = @{ $self->CONFIG->{hash_fields} };
	for my $hash_field (@hash_fields) {
		$self->{$hash_field} = Load($self->{$hash_field});
	}

	return 1;
}

sub convert_to_string {
	my $self = shift;
	my @hash_fields = @{ $self->CONFIG->{hash_fields} };
	for my $hash_field (@hash_fields) {
		$self->{$hash_field} = Dump($self->{$hash_field});
	}

	return 1;
}

1
