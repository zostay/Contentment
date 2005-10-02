package Contentment::Generator;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Contentment::Generator - Provides the contract and generic implementation of the Contentment generator interface

=head1 SYNOPSIS

  use Contentment::Generator;

  my $generator = Contentment::Generator->new;
  $generator->set_generated_kind(sub { 'text/plain' });
  $generator->set_property(title => 'Generic Generator');
  $generator->set_property(description => 'This is a very simple example.');
  $generator->set_generator(sub { print "Hello World!\n" });

  $generator->generate;

=head1 DESCRIPTION

At the center of each response is the generator. A generator is responsible for sending a response to the user and must implement a few methods. This class provides a simple way of returning simple generators. This documentation should be used if you need a generator capable of something more specific.

=head2 GENERATOR CONTRACT

This is the list of methods that a generator class must implement and the expected parameters, output, and return values. We assume C<$generator> to be some instance of the class (or it could just be a variable containing the class name).

=over

=item my $value = $generator-E<gt>get_property($key)

This method must exist and returns whatever information is appropriate. For generators based on files, it might return information for keys naming values returned from the C<stat> operator. This is anything you want.

=item @keys = $generator-E<gt>properties

This method must exist and returns a list of all strings (or all known/common if it's not possible or feasible to list all of them) that may be used as keys into the C<get_property> method.

=item $kind = $generator-E<gt>generated_kind(%args)

Returns a string representing the name of the format the generator generates.

=item $result = $generator-E<gt>generate(%args)

This method should print to STDOUT the output of the generator. It may return whatever result seems appropriate (it will be ignored if it's run as the top-level response).

=back

=head2 GENERIC IMPLEMENTATION

For very simple situations (for example, returning errors), this class provides a very generic implementation. See the L</"SYNOPSIS"> for an overview of how to use it.

=over

=item $generator = Contentment::Generator-E<gt>new

Creates a new generator object instance.

=cut

sub new {
	my $class = shift;
	return bless {
		generated_kind => sub { '' },
		generator      => sub {},
		properties     => {},
	}, $class;
}

=item $generator-E<gt>set_generated_kind($code)

Sets the code reference that will be passed the arguments given to C<generated_kind> and should return the string kind name for the generated type. If this method is not called, then the default is to always return the empty string (C<"">), which means the kind is unknown.

=cut

sub set_generated_kind {
	my $self = shift;
	$self->{generated_kind} = shift;
}

=item $kind = $generator-E<gt>generated_kind(%args)

Runs the subroutine provided by the C<set_generated_time> method or use the default, which returns the empty string.

=cut

sub generated_kind {
	my $self = shift;
	$self->{generated_kind}->(@_);
}

=item $generator-E<gt>set_property($key, $value)

Sets a property for the generator.

=cut

sub set_property {
	my $self = shift;
	my $key  = shift;
	$self->{properties}{$key} = shift;
}

=item $value = $generator-E<gt>get_property($key)

Returns properties that are set via the C<set_property> method.

=cut

sub get_property {
	my $self = shift;
	my $key  = shift;
	$self->{properties}{$key};
}

=item @keys = $generator-E<gt>properties

Returns all the keys that have been set via the C<set_property> method.

=cut

sub properties {
	my $self = shift;
	keys %{ $self->{properties} };
}

=item $generator-E<gt>set_generator($code)

Sets the subroutine that is used to handle the call to C<generate>. If this method is not called, the default generator does nothing.

=cut

sub set_generator {
	my $self = shift;
	$self->{generator} = shift;
}

=item $result = $generator-E<gt>generate(%args)

This basically just calls the subroutine passed to the C<set_generator> method passing the given arguments and returning the result of the given code reference. If C<set_generator> wasn't called, this method does nothing.

=cut

sub generate {
	my $self = shift;
	$self->{generator}->(@_);
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
