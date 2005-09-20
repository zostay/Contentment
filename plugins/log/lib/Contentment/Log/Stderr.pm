package Contentment::Log::Stderr;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Contentment::Log::Stderr - Log handler that logs to STDERR

=head1 SYNOPSIS

  # in init.yml:
  hooks:
    Contentment::Log::error:
      sub: Contentment::Log::Stderr::log

=head1 DESCRIPTION

This is a really basic log handler that sends all log data to STDERR. This is useful when Contentment is running as a CGI as STDERR is generally captured and redirected to the web server's error log.

=cut

sub log {
	my $msg = shift;

	my $date = localtime;
	print STDERR "[$date] [$msg->{level}] $msg->{message}\n";
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
