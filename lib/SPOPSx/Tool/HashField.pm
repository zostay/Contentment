package SPOPSx::Tool::HashField;

use strict;
use warnings;

our $VERSION = '0.02';

use YAML qw(Load Dump);

=head1 NAME

SPOPSx::Tool::HashField - A SPOPS extension allowing for the storage of Perl hashes

=head1 SYNOPSIS

  %conf = (
      table_alias => {
          # ...
          hash_fields => [ qw/ arguments locals results / ],
          # ...
      }
  );

=head1 DESCRIPTION

B<NOTE:> This module will probably be made more general and extracted into its own distribution at some point.

This allows for the storage of Perl hashes in a database field. This uses L<YAML> to perform the marshalling and unmarshalling. This is handy because you can use third-party tools to update the stored hashes with relative ease and the hashes are readable even in other languages that have a YAML model. Only the top level needs to be a hash. The data structure can be arbritraily deep.

=cut

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

=head1 SEE ALSO

L<SPOPS>, L<YAML>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
