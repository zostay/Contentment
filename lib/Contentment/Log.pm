package Contentment::Log;

use strict;
use warnings;

our $VERSION = '0.02';

use Carp;
use Contentment::Hooks;

=head1 NAME

Contentment::Hooks - Handles logging for Contentment

=head1 DESCRIPTION

This logger is smart enough to queue up the messages and allows for multiple logs. This uses the L<Contentment::Hooks> system to actually post the logs. Each log has a hook named "Contentment::Log::I<logname>".

=cut

my @queue;
sub default_logger {
	my $args = shift;

	my $count = Contentment::Hooks->count('Contentment::Log::error');
	if ($count > 1) {
		Contentment::Hooks->unregister(
			'Contentment::Log::error',
			'default_logger',
		);

		while (my $msg = pop @queue) {
			Contentment::Hooks->call("Contentment::Log::error", $msg);
		}
	} else {
		push @queue, $args;
	}
}

Contentment::Hooks->register(
	hook  => 'Contentment::Log::error',
	code  => \&default_logger,
	order => -99,
	id    => 'default_logger',
);

=over

=item Contentment::Log-E<gt>log(\%args);

This is the most basic log method. All the other methods are just wrappers for this one. This method takes the following arguments:

=over

=item name (required)

The name of the log to send the message to. This method will then call the hook named C<"Contentment::Log::$name">.

=item message (required)

This is a string that will be passed as the message to the hook handlers. This string may be formatted as for C<sprintf> with the interpolation variables passed in the "args" argument. (The reason for offering this kind of interpolation is that I hope to add internationalization at some later point, which will be more easily done this way.)

=item args (optional)

This is a reference to an array of values used to interpolate the "message" argument.

=item level (optional)

This argument is specific to the "error" log, but is shown here since it's common. This should be one of the following string values:

=over

=item DEBUG

=item INFO

=item WARNING

=item ERROR

=back

These are just suggestions, but these are the levels currently used by Contentment internally. Additional log levels may be added in the future.

=back

In addition to these arguments, any other named argument may be passed to contain other information.

The hook handlers will be passed this reference with the message string interpolated, but otherwise unchanged.

=cut

sub log {
	my $class = shift;
	my $args  = shift;

	$args->{message} = sprintf $args->{message}, @{ $args->{args} || [] };
	Contentment::Hooks->call("Contentment::Log::$args->{name}", $args);	
}

=item Contentment::Log-E<gt>debug(@msg, \@args)

This is a shortcut for calling:

  Contentment::Log->log(
      name    => "error", 
	  level   => "DEBUG", 
	  message => join($,, @msg), 
	  args    => $args,
  );

The C<\@args> array is optional.

=item Contentment::Log-E<gt>info(@msg, \@args)

This is a shortcut for calling:

  Contentment::Log->log(
      name    => "error", 
	  level   => "INFO", 
	  message => join($,, @msg), 
	  args    => $args,
  );

The C<\@args> array is optional.

=item Contentment::Log-E<gt>warning(@msg, \@args)

This is a shortcut for calling:

  Contentment::Log->log(
      name    => "error", 
	  level   => "WARNING", 
	  message => join($,, @msg), 
	  args    => $args,
  );

The C<\@args> array is optional.

=item Contentment::Log-E<gt>error(@msg, \@args)

This is a shortcut for calling:

  Contentment::Log->log(
      name    => "error", 
	  level   => "ERROR", 
	  message => join($,, @msg), 
	  args    => $args,
  );

The C<\@args> array is optional.

=cut

my @error_loggers = qw( DEBUG INFO WARNING ERROR );
for my $error_logger (@error_loggers) {
	my $method = lc $error_logger;
	no strict 'refs';
	*{"Contentment::Log::$method"} = sub {
		my $class = shift;

		my $args = ref $_[-1] eq 'ARRAY' ? pop @_ : [];
		Contentment::Log->log({
			name    => 'error',
			level   => $error_logger,
			message => join($,||'', @_),
			args    => $args,
		});
	};
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COYPRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
