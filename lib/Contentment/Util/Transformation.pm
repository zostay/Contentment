package Contentment::Util::Transformation;

use strict;
use warnings;

use Log::Log4perl;
my $log = Log::Log4perl->get_logger('Contentment::Util::Transformation');

our $VERSION = '0.01';

=head1 NAME

Contentment::Util::Transformation - Find the best transformation available

=head1 DESCRIPTION

This is a helper module to hold all the "guts" to the "apply_transformation"
component. This component is responsible for determining which is the most
appropriate transformation or series of transformations available.

This is done by creating a directed graph of the possible transformations and
then finding the shortest path using Dijkstra's algorithm. (That is, an A*
search with the heuristic value (H) set to zero for all nodes.)

=cut

sub new {
	my $class = shift;

	bless {}, $class;
}

sub add_transformation {
	my ($self, $comp, $input_kinds, $output_kind, $cost) = @_;

	$cost < 0 and $cost = 0; # Dijkstra's doesn't handle negative path costs

	for my $input_kind (@$input_kinds) {
		$log->debug("Transformation adding $input_kind -> $output_kind at cost $cost");
		push @{ $self->{$input_kind} }, {
			cost        => $cost,
			input_kind  => $input_kind,
			output_kind => $output_kind,
			comp        => $comp,
			path_cost   => $cost,
		};
	}
}

sub shortest_path {
	my ($self, $original, $final) = @_;

	$log->debug("Transformation attempting to find shortest path $original => $final");

	return undef unless defined $self->{$original};

	my @closed_list;
	my @open_list = sort { $$a{path_cost} <=> $$b{path_cost} } @{ $self->{$original} };
	my $final_path;

	$log->is_debug and
		$log->debug("Transformation starting with open list: ", 
			join(', ', map "$$_{input_kind} -> $$_{output_kind}", @open_list));

ASTAR:
	until (!@open_list) {
		my $current = shift @open_list;
		push @closed_list, $current;

		if ($current->{output_kind} eq $final) {
			$final_path = $current;
			last ASTAR;
		}

		for my $transform (@{ $self->{$current->{output_kind}} }) {
			unless (grep { $_->{comp} eq $transform->{comp} } @open_list) {
				push @open_list, $transform;
				$transform->{parent} = $current;
				$transform->{path_cost} += $current->{path_cost};
			} else {
				if ($current->{path_cost} + $transform->{cost} < $transform->{path_cost}) {
					$transform->{parent} = $current;
					$transform->{path_cost} = $current->{path_cost} + $transform->{cost};
				}
			}
		}

		@open_list = sort { $$a{path_cost} <=> $$b{path_cost} } @open_list;
	}

	if (defined $final_path) {
		my @result;
		for (my $current = $final_path; defined $current; $current = $current->{parent}) {
			push @result, $current->{comp};
		}
		return \@result;
	} else {
		return undef;
	}
}

1
