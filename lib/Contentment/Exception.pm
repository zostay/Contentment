package Contentment::Exception;

use strict;
use warnings;

our $VERSION = 0.011_028;

use Exception::Class (
    'Contentment::Exception' => {
        fields => [ 'status', 'title', 'details', 'generator' ],
    }
);

=head1 NAME

Contentment::Exception - Used to throw exceptions in Contentment

=head1 SYNOPSIS

  use Contentment::Exception;

  # Throw a general exception...
  Contentment::Exception->throw(
      status  => 404,
      title   => 'Not Found',
      message => 'Couldn't find it.'
      details => 'Well, it's kind of a long story. First, I looked...',
  );

=head1 DESCRIPTION

Exceptions for Contentment based upon L<Exception::Class>. In addition to the features of that class, it provides these additional fields:

=over

=item status

This is the HTTP status that the exception should result in if it propogates all the way to the top-level request. The default is 500.

=item title

This is the title of the error. This defaults to the status code names found in RFC-2616. (These can be found at the W3C web site: L<http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html>). A table of these is stored in the C<%Contentment::Exception::status_code_titles> variable.

=item details

This should be any additional debugging information that should be associated with the message, but not shown to general users.

=item location

If the exception is set to use a 3xx status code (in particular, 301 Moved Permanently and 302 Found), this is the URI that the client should be resent to. If the exception reaches the top level.

=back

=cut

our %status_code_titles = (
    100 => 'Continue',
    101 => 'Switching Protocols',
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',
    203 => 'Non-Authoritative Information',
    204 => 'No Content',
    205 => 'Reset Content',
    206 => 'Partial Content',
    300 => 'Multiple Choices',
    301 => 'Moved Permanently',
    302 => 'Found',
    303 => 'See Other',
    304 => 'Not Modified',
    305 => 'Use Proxy',
    307 => 'Temporary Redirect',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    402 => 'Payment Required',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    407 => 'Proxy Authentication Required',
    408 => 'Request Timeout',
    409 => 'Conflict',
    410 => 'Gone',
    411 => 'Length Required',
    412 => 'Precondition Failed',
    413 => 'Request Entity Too Large',
    414 => 'Request-URI Too Long',
    415 => 'Unsupported Media Type',
    416 => 'Requested Range Not Satisfiable',
    417 => 'Expectation Failed',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported',
);

sub new {
    my $class = shift;
    my %args  = @_;

    if (!defined $args{status}) {
        $args{status} = 500;
    }

    if (!defined $args{title}) {
        $args{title} = $status_code_titles{ $args{status} };
    }

    return $class->SUPER::new(%args);
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp E<lt>hanenkamp@cpan.orgE<gt>.  All 
Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut

1
