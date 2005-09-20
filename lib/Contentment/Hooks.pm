package Contentment::Hooks;

use strict;
use warnings;

our $VERSION = '0.03';

use Carp;

=head1 NAME

Contentment::Hooks - Runs the Contentment hook system

=head1 SYNOPSIS

  use Contentment::Hooks;

  # register Foo:bar() for hook 'foo' with order weight 50.
  Contentment::Hooks->register(
	  hook  => 'foo', 
	  name  => 'Foo',
	  code  => \&Foo::bar, 
	  order => 50,
  );

  # register Foo::baz() for hook 'foo' with default priority
  Contentment::Hooks->register(hook => 'foo', code => \&Foo::baz);

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

=item Contentment::Hook-E<gt>register(%args)

This registers a handler for a hook. All arguments are passed in a hash:

=over

=item hook (required)

The name of the hook the handler is registering for.

=item code (required)

The subroutine that will handle the hook.

=item order (optional: defaults to 0)

The order weight the handler should have. Lower numbers will be run first and higher numbers will be run last. It's recommended that these values be kept between -99 and 99.

=item name (optional)

Some hooks require names to be used so that each name can be handled differently. How the names are used will depend upon the hook, so see the documentation for the hook for details.

=item id (optional)

In some cases, it is desirable to unregister a hook handler. By passing this id, it can be passed to the C<unregister> method to remove this hook. If no id is given, one will be assigned.

=cut

my $ids = 0;
sub register {
	my $self = shift->instance;
	my %args = @_;

	croak "Missing required argument 'hook'." unless $args{hook};
	croak "Missing required argument 'code'." unless $args{code};

	unless ($args{id}) {
		do {
			$args{id} = ++$ids;
		} while (grep { $_->{id} eq $args{id} } @{ $self->{$args{hook}} || [] });
	} elsif (grep { $_->{id} eq $args{id} } @{ $self->{$args{hook}} || [] }) {
		croak "Hook handler id '$args{id}' is not unique for hook '$args{hook}'.";
	}

	$args{order} ||= 0;

	my @code = 
		sort { $a->{order} <=> $b->{order} }
		     (@{ $self->{$args{hook}} || [] }, \%args);	

	$self->{$args{hook}} = \@code;

	return;
}

=item Contentment::Hook-E<gt>unregister($hook, $id)

Removed the hook handler for hook C<$hook> registered with id C<$id>.

=cut

sub unregister {
	my $self = shift->instance;
	my $hook = shift;
	my $id   = shift;

	$self->{$hook}= [ grep { $_->{id} ne $id } @{ $self->{$hook} || [] } ];

	return;
}

=item Contentment::Hook-E<gt>count($hook)

Count the number of registered hooks for the hook C<$hook>.

=cut

sub count {
	my $self = shift->instance;
	my $hook = shift;

	return scalar(@{ $self->{$hook} || [] });
}

=item Contentment::Hook-E<gt>count_named($hook, $name)

Count the number of registered hooks for the hook C<$hook> named C<$name>.

=cut

sub count_named {
	my $self = shift->instance;
	my $hook = shift;
	my $name = shift;

	my @named_hooks = grep { $_->{name} eq $name } @{ $self->{$hook} || [] };

	return scalar(@named_hooks);
}

=item Contentment::Hook-E<gt>call($hook, @args)

Call the hook named C<$hook> and pass arguments C<@args>. The arguments are optional.

Each subroutine registered for the hook is executed in order. The return value of the final hook is returned.

=cut

sub call {
	my $self = shift->instance;
	my $name = shift;

	my @hooks = @{ $self->{$name} || [] };
	
	my $result;
	for my $hook (@hooks) {
		if (wantarray) {
			$result = [ $hook->{code}->(@_) ];
		} else {
			$result = $hook->{code}->(@_);
		}
	}

	return wantarray ? @$result : $result;
}

=item Contentment::Hook-E<gt>call_named($hook, $name, @args)

Call only handlers for C<$name> registered for the hook named C<$hook> and pass arguments C<@args>. The arguments are optional.

Each subroutine registered for the hook is executed in order. The return value of the final hook is returned.

=cut

sub call_named {
	my $self = shift->instance;
	my $name = shift;
	my $handler_name = shift;

	my @hooks = grep { $_->{name} eq $handler_name } @{ $self->{$name} || [] };
	
	my $result;
	for my $hook (@hooks) {
		if (wantarray) {
			$result = [ $hook->{code}->(@_) ];
		} else {
			$result = $hook->{code}->(@_);
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
  while ($iter->next) {
	  # Pass a handler it's data associated by name
	  $iter->call($data{$iter->name});
  }

=over

=item $test = $iter-E<gt>next

Moves the iterator to point to the next hook handler. This method returns a true value if there is another handler to run and false if there are no more.

=cut

sub next {
	my $self = shift;
	
	if (@{ $self->{hooks} }) {
		$self->{current} = shift @{ $self->{hooks} };
		return 1;
	} else {
		return '';
	}
}

=item $iter-E<gt>call(@args)

Calls the current handler for the hook with the given arguments. This method returns the value returned by the nested subroutine.

=cut

sub call {
	my $self = shift;
	
	return $self->{current}{code}->(@_);
}

=item $name = $iter-E<gt>name

Returns the name that was associated with the handler according to the "name" argument when the handler was registered. Returns C<undef> if no such argument was given.

=cut

sub name { return shift->{current}{name} }

=item $name = $iter-E<gt>order

Returns the order weight that the handler was registered with. Returns 0 if none was given.

=cut

sub order { return shift->{current}{order} }

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1

