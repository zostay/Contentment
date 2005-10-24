package Contentment::Log::Stderr;

use strict;
use warnings;

our $VERSION = '0.02';

=head1 NAME

Contentment::Log::Stderr - Log handler that logs to STDERR

=head1 SYNOPSIS

  # in init.yml:
  hooks:
    Contentment::Log::error:
      sub: Contentment::Log::Stderr::log

=head1 DESCRIPTION

This class merely defines a few hook handlers. All the log handlers listed here are simple and send their data to STDERR. This is useful when Contentment is running as a CGI when STDERR is captured and redirected tot he web server's error log.

=head2 HOOK HANDLERS

=over

=item Contentment::Log::Stderr::log

This method reports all log information sent to it.

=cut

sub log {
	my $msg = shift;

    # Yes! We always log stuff.
    if ($msg->{would_log}) {
        return 1;
    }

    # Log it!
    else {
        my $date = localtime;
        print STDERR "[$date] [$msg->{level}] $msg->{message}\n";
        return 1;
    }
}

=item Contentment::Log::Stderr::info_warning_error_log

This method reports all log information sent to it with log levels "INFO", "WARNING", or "ERROR".

=cut

sub info_warning_error_log {
    my $msg = shift;

    return 0 if $msg->{level} eq 'DEBUG';

    # We log it if we got this far!
    if ($msg->{would_log}) {
        return 1;
    }

    # Log it!
    else {
        my $date = localtime;
        print STDERR "[$date] [$msg->{level}] $msg->{message}\n";
        return 1;
    }
}

=item Contentment::Log::Stderr::warning_error_log

Logs anything with level "WARNING" or "ERROR". Logs nothing else.

=cut

sub warning_error_log {
    my $msg = shift;

    return 0 if $msg->{level} =~ /^(?:DEBUG|INFO)$/;

    # If we've gotten this far, we log it.
    if ($msg->{would_log}) {
        return 1;
    }

    # Log it.
    else {
        my $date = localtime;
        print STDERR "[$date] [$msg->{level}] $msg->{message}\n";
        return 1;
    }
}

=item Contentment::Log::Stderr::error_log

Only logs message with level "ERROR".

=cut

sub error_log {
    my $msg = shift;

    return 0 unless $msg->{level} eq 'ERROR';

    # If we got here, we log it!
    if ($msg->{would_log}) {
        return 1;
    }

    # Log it.
    else {
        my $date = localtime;
        print STDERR "[$date] [$msg->{level}] $msg->{message}\n";
        return 1;
    }
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
