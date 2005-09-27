package Contentment::Transform;

use strict;
use warnings;

our $VERSION = '0.06';

use Contentment;
use Contentment::Hooks;
use Contentment::Log;
use Contentment::Request;
use Contentment::Response;
use IO::NestedCapture ':subroutines';

=head1 NAME

Contentment::Transform - Applies file content transformation

=head1 SYNOPSIS

  use Contentment::Transform;
  use IO::NestedCapture 'capture_in_out';

  my $transformer = Contentment::Transform->instance;

  my $in = IO::NestedCapture->get_next_in;
  # print the input to $in...

  capture_in_out {
      $transformer->apply_transformation(
          from => 'LaTeX',
          to   => 'PDF',
      );
  };

  # $out here contains the output of the transformation
  my $out = IO::NestedCapture->get_last_out;

=head1 DESCRIPTION

This module performs several tasks. The primary purpose of this module is to take generated content in some format A and find a way to transform that data into format A'.

The current format of the content is assumed to be that of the value stored in the C<top_level()> accessor of L<Contentment::Response>.  The "kind" is just a name for the file format (often a MIME-type might be convenient, but it's just a string name). The goal for the transformation plugin is to find the cheapest translation possible to get from this kind into the final kind. The final kind is determined by the C<final_kind()> accessor of L<Contentment::Request>. This module attempts to find zero or more transformations that will coerce the document of the original kind into a document of the final kind.

Each transformer accepts data from a given input kind and produces a document of a given output kind. (Given when the transformer is registered using the C<add_transformation()> method.) Transformers are subroutines similar to hook handlers (see L<Contentment::Hooks>), except they are registered using the C<add_transformation()> method of this class. Each transformation defines a C<cost> attribute, which associates a numeric cost to the transformation---the higher the value the more "costly" the transformation. This module will attempt to use the cheapest transformation available, but may use any found.

=head2 PATH FINDING

When searching for the best choice of transformers to get from original kind A to final kind A', we use Dijkstra's shortest path algorithm. (That is, an A* search with the heuristic value (H) set to zero for all nodes.)

=cut

my $instance;
sub instance {
	return $instance if $instance;

	my $class = shift;

	$instance = my $self = bless {}, $class;

	return $self;
}

my $transformation_id = 1;
sub add_transformation {
	my $self        = shift;
	my $code        = shift;
	my $input_kind  = shift;
	my $output_kind = shift;
	my $cost        = shift;

	$cost < 0 and $cost = 0; # Dijkstra's doesn't handle negative path costs

	Contentment::Log->debug("Transformation adding %s -> %s at cost %d.", [$input_kind, $output_kind, $cost]);
	push @{ $self->{$input_kind} }, {
		id          => $transformation_id++,
		input_kind  => $input_kind,
		output_kind => $output_kind,
		cost        => $cost,
		code        => $code,
		path_cost   => $cost,
	};
}

sub shortest_path {
	my $self     = shift;
	my $original = shift;
	my $final    = shift;

	Contentment::Log->debug("Transformation attempting to find shortest path %s => %s", [$original,$final]);

	return undef unless defined $self->{$original};

	my @closed_list;
	my @open_list = sort { $$a{path_cost} <=> $$b{path_cost} } @{ $self->{$original} };
	my $final_path;

	Contentment::Log->debug("Transformation starting with open list: %s",
			[join(', ', map "$$_{input_kind} -> $$_{output_kind}", @open_list)]);

ASTAR:
	until (!@open_list) {
		my $current = shift @open_list;
		push @closed_list, $current;

		if ($current->{output_kind} eq $final) {
			$final_path = $current;
			last ASTAR;
		}

		for my $transform (@{ $self->{$current->{output_kind}} }) {
			unless (grep { $_->{id} eq $transform->{id} } @open_list) {
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
			push @result, $current->{code};
		}
		return \@result;
	} else {
		return undef;
	}
}

=item $transform-E<gt>apply_transformation(%args)

Attempts to transform the input in C<STDIN> from one type to another and places that output on C<STDOUT>. Currently accepts two arguments in C<%args>:

=over

=item to

If given, this chooses the kind it will attempt to change the input into. Otherwise it will default to the value of C<Contentment::Request-E<gt>final_kind>.

=item from

If given, this chooses the kind it will assume the output is currently in. Otherwise it will default to the value of C<Contentment::Response-E<gt>top_kind>.

=back

=cut

sub apply_transformation {
	my $self = shift;
	my %args  = @_;

	# Step 1: Determine the original kind.
	my $original_kind = $args{from} || Contentment::Response->top_kind;
	Contentment::Log->debug("Transformation #1: original kind is %s", [$original_kind]);

	# Step 2: Determine the final kind.
	my $final_kind = $args{to} || Contentment::Request->final_kind;
	Contentment::Log->debug("Transformation #2: final kind is %s", [$final_kind]);

	if ($final_kind eq '') {
		Contentment::Log->debug("Transformation #2: treating unknown final kind as original kind %s", [$original_kind]);
		$final_kind = $original_kind;
	}

	if ($original_kind eq '') {
		Contentment::Log->debug("Transformation #2: treating unknown original kind as final kind %s", [$final_kind]);
		$original_kind = $final_kind;
	}

	# Step 3: Do we need to perform any transformations?
	if ($original_kind eq $final_kind) {
		Contentment::Log->debug("Transformation #3: original kind is final kind, no transformation necessary.");
		print <STDIN>;
		return;
	}
	Contentment::Log->debug("Transformation #3: original kind is not final kind, transformation continuing.");

	# Step 4: Attempt to find the cheapest transformation available.
	my $transforms = $self->shortest_path($original_kind, $final_kind);

	unless (defined $transforms and @$transforms > 0) {
		Contentment::Log->error("Oop! Now way to get from %s kind to %s kind.", [$original_kind, $final_kind]);
		Contentment::Log->error("Outputting original untransformed, this could get ugly.");

		print <STDIN>;
	} else {
		Contentment::Log->debug("Transformation #4: transformation from original to final in %d steps.",[scalar(@$transforms)]);

		# Setup input
		my $in = IO::NestedCapture->get_next_in;
		while (<STDIN>) {
			print $in $_;
		}

		# Step 5: Use the transforms to get us there.
		my $pass = 0;
		my $output;
		for my $transform (@$transforms) {
			Contentment::Log->debug("Transformation #5: Applying transformation %s", [$transform]);

			IO::NestedCapture->set_next_in($output)
				if $pass++ > 0;

			# Generate each file with the correct input and capture the output.
			capture_in_out {
				$transform->();
			};
			$output = IO::NestedCapture->get_last_out;
		}

		print <$output>;
		Contentment::Response->top_kind($final_kind);
	}
}

=head2 HOOK HANDLERS

=over

=item Contentment::Transform::transform

This handler is for the "Contentment::Response::end" hook.

=cut

sub transform {
	my $transform = Contentment::Transform->instance;
	$transform->apply_transformation;
}

=item Contentment::Transform::begin

This handler is the for the "Contentment::begin" hook and is used to call the "Contentment::Transform::begin" hook.

=cut

sub begin {
	Contentment::Hooks->call(
		"Contentment::Transform::begin", Contentment::Transform->instance
	);
}

=back

=head2 HOOKS

=over

=item Contentment::Transform::begin

Handlers for this hook receive a C<Contentment::Transform> instance on which they can register transformations.

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
