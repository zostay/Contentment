package Contentment::Hooks;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Contentment::Hooks - Runs the Contentment hook system

=head1 SYNOPSIS

  use Contentment::Hooks;

  # register Foo:bar() for hook 'foo' with order weight 50.
  Contentment::Hooks->register('foo', \&Foo::bar, 50);

  # register Foo::baz() for hook 'foo' with default priority
  Contentment::Hooks->register('foo', \&Foo::baz);

  # run the 'foo' hook with the given arguments
  Contentment::Hooks->call('foo', 0, foo => 7);

  # This would call:
  #   &Foo::baz(0, foo => 7);
  #   &Foo::bar(0, foo => 7);
  # Default priority = 0 and lower order weights run first.
 
=head1 DESCRIPTION

Contentment depends heavily upon the hook system to allow each aspect of the system to be overridden by one or more plugins providing features to the system. These plugins register themselves with the hooks they wish to be dropped into and then those registered bits of code are run when the named hook is.

=head2 HOOK API

=over

=cut

my $instance;
sub instance {
	return $instance if $instance;
	return $instance = bless {}, shift;
}

=item Contentment::Hook-E<gt>register($name, $code, $weight)

Register the code reference C<$code> to run with hook C<$name> with a order weight of C<$weight>. The order weight is optional and defaults to 0 if not given. Code registered with a lower weight will run before code registered with a higher weight.

=cut

sub register {
	my $self   = shift->instance;
	my $name   = shift;
	my $code   = shift;
	my $weight = shift || 0;

	my @code = 
		sort { $a->[0] <=> $b->[1] }
		     (@{ $self->{$name} || [] }, [ $code, $weight ]);	

	$self->{$name} = \@code;

	return;
}

=item Contentment::Hook-E<gt>call($name, @args)

Call the hook named C<$name> and pass arguments C<@args>. The arguments are optional.

Each subroutine registered for the hook is executed in order. The return value of the final hook is returned.

=cut

sub call {
	my $self = shift->instance;
	my $name = shift;

	my @hooks = @{ $self->{$name} || [] };
	
	my $result;
	for my $hook (@hooks) {
		if (wantarray) {
			$result = [ $hook->[0]->(@_) ];
		} else {
			$result = $hook->[0]->(@_);
		}
	}

	return wantarray ? @$result : $result;
}

=item $iterator = Contentment::Hook-E<gt>call_iterator($name)

This returns an object that may be used to iterate through all the hook subroutines manually. This is handy if the hooks are permitted to manipulate arguments, have significant return values, or need to have the output of each fed one into the other, etc. This method is reentrant, so if you want to recursively iterate through hooks, the iterators will not clobber each other.

See L</"CALL ITERATOR"> for more information.

=cut

sub call_iterator {
	my $self = shift->instance;
	my $name = shift;

	my @hooks = @{ $self->{$name} || [] };

	return bless { hooks => \@hooks }, 'Contentment::Hooks::Iterator';
}

package Contentment::Hooks::Iterator;

=back

=head2 CALL ITERATOR

Using a call iterator (via the C<call_iterator> method), you can run each hook subroutine one at a time.

  my $iter = Contentment::Hooks->call_iterator('foo');
  while ($iter->has_next) {
	  $iter->call_next(@args);
  }

=over

=item $test = $iter-E<gt>has_next

Returns a true value when there is another subroutine left to call in the iterator. Returns a false value otherwise.

=cut

sub has_next {
	my $self = shift;
	return @{ $self->{hooks} };
}

=item $iter-E<gt>call_next(@args)

Calls the next subroutine for the hook with the given arguments. If this is called when C<has_next> returns false, an exception will be thrown. This method returns the value returned by the nested subroutine.

=cut

sub call_next {
	my $self = shift;
	
	die "No more hook subroutines left to run." unless $self->has_next;

	my $hook = shift @{ $self->{hooks} };
	return $hook->[0]->(@_);
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1

