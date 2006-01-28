package Contentment::Log;

use strict;
use warnings;

our $VERSION = '0.011_031';

use Carp;
use Contentment::Hooks;

=head1 NAME

Contentment::Hooks - Handles logging for Contentment

=head1 DESCRIPTION

This logger is smart enough to queue up early error messages and allows for multiple logs. This uses the L<Contentment::Hooks> system to actually post the logs. Each log has a hook named "Contentment::Log::I<logname>".

This log API doesn't really do much on it's own. Hooks must be registered for it to really do anything. You might want to see the information in the Log plugin for Contentment, since it is generally used to setup the actual file logging and such.

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

		while (my $msg = shift @queue) {
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

This is the most basic log method. All the other methods are just wrappers for this one. 

It is normally assumed thet C<%args> will be passed via an anonymous reference. Be aware that C<log()> will make changes to the reference passed in, in the interest of speed. Mostly, it will replace the C<message> argument with an interpolated version. However, other changes might occur to (depending on if the code has changed and this documentation has not).

This method takes the following arguments:

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

=item would_log (optional)

If this argument is specified and set to a true value, then the handlers registered are not supposed to log anything, but return whether or not they would log anything. The logical disjunction (OR) of all the results will be returned.

=back

In addition to these arguments, any other named argument may be passed to contain other information.

The hook handlers will be passed this reference with the message string interpolated, but otherwise unchanged.

This method will returned a logical disjunction (OR) of all the return values from all the handlers. When the C<would_log> argument is passed with a true value this result will be whether or not any log handler will use the logged information. When the C<would_log> argument is false or not passed, this result will be whether or not any log handler did successfully do something with the log.

=cut

sub log {
	my $class = shift;
	my $args  = shift;

    # Interpolate the message with the given arguments
	$args->{message} = sprintf $args->{message}, @{ $args->{args} || [] };

    # Iterate through the log handlers and logically-OR the results together
    my $iter 
        = Contentment::Hooks->call_iterator("Contentment::Log::$args->{name}");
    my $result = 0;
    while ($iter->next) {
        $result ||= $iter->call($args);
    }

    # Return the result
    return $result;
}

=item Contentment::Log-E<gt>would_log(\%args)

This method is exactly the same as the C<log()> method with a couple exceptions. First, it makes sure the C<would_log> argument is set to a true value. Second, it does not perform any string interpolation of the given message and args.

It can be used as a quick short cut to see if a call to C<log()> will have any affect:

  Contentment::Log->would_log(name => 'error', level => 'DEBUG')
      && Contentment::Log->debug(
             # Some expensive operation
         );

This method will also use the log named "error" by default. Therefore, the following is the same as before:

  Contentment::Log->would_log(level => 'DEBUG')
      && Contentment::Log->debug(
             # Some expensive operation
         );

=cut

sub would_log {
    my $class = shift;
    my $args = shift;

    # Set-up the defaults
    $args->{would_log}   = 1;
    $args->{name}      ||= 'error';

    # Iterate through the log handlers and logically-OR the results together
    my $iter 
        = Contentment::Hooks->call_iterator("Contentment::Log::$args->{name}");
    my $result = 0;
    while ($iter->next) {
        $result ||= $iter->call($args);
    }

    # Return the result
    return $result;
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

=head2 CUSTOM LOG HANDLERS

If you wish to write a custom log handler. You simply need a method that will accept all the arguments passed to the C<log()> method. The C<would_log> argument must be handled such that a true C<would_log> flag doesn't result in logging, but a check to see whether logging will occur.

Log handlers don't need to worry about string interpolation. String interpolation is already handled within the C<log()> method.

=head2 HOOKS

=over

=item Contentment::Log::I<logname>

The system provides the ability for multiple logs. If your module needs a special log for something, you may register for any I<logname> you want and then use the C<log()> method to log there:

  Contentment::Log->log({
      name => 'my_foo_log',
      some_other_custom_foo_arg => 'foo foo FOO!',
      message => 'Log to foo, foo!'
  });

=item Contentment::Log::error

This is the priamry log hook for the system. The error log has much the same functionality as Apache's F<error_log>. (Indeed, the default configuration currently sends all of the information logged to this hook to that file when running under Apache.)

=item Contentment::Log::access

This log is currently not in use, but is planned for use by Contentment. It will be used to record page accesses handled by the system for the creation of statistics.

=back

=head2 HOOK HANDLERS

=over

=item Contentment::Log::default_logger

This is the hook hook handler performs a queue-register-reply role prior to any other hooks being registered for the "Contentment::Log::error" hook.

When the L<Contentment::Log> package is first loaded, this default logger is registered for "Contentment::Log::error". This log handler checks to see if any other handler has been registered between log calls. If no handler has been registered, it queues up messages each time it's called. This will continue until another handler is registered for the hook. Once that happens, the default log handler unregisters itself and replays the queued log. This way, no log messages are lost even though most log handlers are going to be added as plugins late in the game.

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COYPRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
