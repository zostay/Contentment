package Contentment::Test;

use strict;
use warnings;

our $VERSION = '0.011_033';

use Carp;
use HTML::TokeParser;
use HTTP::Request::Common ();
use LWP::UserAgent;
use Test::Builder;
my $Test = Test::Builder->new;

use constant PUT_BACK_NEVER   => 0x00;
use constant PUT_BACK_ON_FIND => 0x01;
use constant PUT_BACK_ON_MISS => 0x02;
use constant PUT_BACK_ALWAYS  => 0x03;

require Exporter;

our @ISA = qw( Exporter );

our @EXPORT = qw(
    parse_html
    tag_with_attrs tag_with_content
    has_tag_with_attrs no_tag_with_attrs
    has_tag_with_content
    user_agent make_url
    GET POST
);

=head1 NAME

Contentment::Test - Helpers for testing Contentment

=head1 SYNOPSIS

  use Contentment::Test;

  my $response = GET('/foo.txt');
  my $content  = GET_BODY('/index.html');

=head1 DESCRIPTION

Provides a bunch of L<Apache::Test>-like helpers without the L<Apache::Test> dependencies.

This class probably has little or no use to end-users and is intended for developers wishing to test Contentment. This documentation is only written with that audience in mind.

=head2 METHODS

=over

=cut

=item $parser = parse_html($text)

Parses the given text using L<HTML::TokeParser>. This parser argument is used to evaluate the given text with some of the other test methods.

=cut

sub parse_html {
    return HTML::TokeParser->new(\$_[0]);
}

=item tag_with_attrs($parser, $tag, $expected_attrs, $put_back_when)

This is a helper used by C<has_tag_with_attrs()> and C<no_tag_with_attrs()>, so those are probably the methods you really want. 

The C<$parser> is the argument returned by the C<parse_html()> method. The C<$tag> is the name of the tag to look for. The C<$expected_attrs> is a hash of expected attributes names and values. If the values are regular expressions, then they are used to match attribute values. The C<$put_back_when> argument determines under which situation, if any, the token should be put back into the parser. This option can be set to one of the imported constants C<PUT_BACK_NEVER>, C<PUT_BACK_ON_MISS>, C<PUT_BACK_ON_FIND>, or C<PUT_BACK_ALWAYS>.

Returns a true value naming the found token on success or dies with a list of errors on a failure to match.

=cut

sub tag_with_attrs {
    my ($parser, $tag, $expected_attrs, $put_back_when) = @_;

    my @misses;
    my @tokens;

    TOKEN:
    while (my $token = $parser->get_token) {
        push @tokens, $token;
        next unless $token->[0] eq 'S';
        next unless $token->[1] eq $tag;
        my $actual_attrs = $token->[2];

#        $Test->diag(qq(AIM <$tag )
#            .join(' ',
#                map  { qq($_=").$expected_attrs->{$_}.q(") }
#                keys %$expected_attrs
#            ).q(>)
#        );

        for my $key (keys %$expected_attrs) {
            my $value = $expected_attrs->{$key};
 
#            $Test->diag(qq(EXPECTED ATTRIBUTE $key="$value"));
            if (!defined $actual_attrs->{$key}) {
#                $Test->diag(qq(MISSES $key=undef));
                push @misses, qq(Tried $token->[4], but attribute "$key" is missing.);
                next TOKEN;
            }
            elsif (ref $value eq 'Regexp') {
                if ($actual_attrs->{$key} !~ /$value/) {
#                    $Test->diag(qq(MISSES $key="$actual_attrs->{$key}"));
                    push @misses, qq(Tried $token->[4], but attribute "$key" doesn't match: "$actual_attrs->{$key}" !~ /$value/.);
                    next TOKEN;
                }
            }
            else {
                if ($actual_attrs->{$key} ne $value) {
#                    $Test->diag(qq(MISSES $key="$actual_attrs->{$key}"));
                    push @misses, qq(Tried $token->[4], but attribute "$key" doesn't match: "$actual_attrs->{$key}" ne "$value".);
                    next TOKEN;
                }
            }
        }

        if ($put_back_when & PUT_BACK_ON_FIND) {
            $parser->unget_token(@tokens);
        }
#        $Test->diag(qq(HIT $token->[4]));
        return qq(Found $token->[4].);
    }

    if ($put_back_when & PUT_BACK_ON_MISS) {
        $parser->unget_token(@tokens);
    }
    die \@misses;
}

=item tag_with_content($parser, $tag, $expected_content, $put_back_when)

This is a helper used by C<has_tag_with_content()> and C<no_tag_with_content()>, so those are probably the methods you really want. 

The C<$parser> is the argument returned by the C<parse_html()> method. The C<$tag> is the name of the tag to look for. The C<$expected_content> is a scalar or regular expression used to match an attribute's content. The C<$put_back_when> argument determines under which situation, if any, the token should be put back into the parser. This option can be set to one of the imported constants C<PUT_BACK_NEVER>, C<PUT_BACK_ON_MISS>, C<PUT_BACK_ON_FIND>, or C<PUT_BACK_ALWAYS>.

Returns a true value naming the found token on success or dies with a list of errors on a failure to match.

=cut

sub tag_with_content {
    my ($parser, $tag, $expected_content, $put_back_when) = @_;

    my @tokens;
    my @misses;

    TOKEN:
    while (my $token = $parser->get_token) {
        push @tokens, $token;
        next unless $token->[0] eq 'S';
        next unless $token->[1] eq $tag;

        my $text_token = $parser->get_token;
        if ($text_token->[0] ne 'T') {
            push @misses, qq(Tried $token->[4], but token after tag is not text.);
            $parser->unget_token($text_token);
            next TOKEN;
        } else {
            push @tokens, $text_token;
        }

        my $actual_text = $text_token->[1];
        
        if (ref $expected_content eq 'Regexp') {
            if ($actual_text !~ /$expected_content/) {
                push @misses, qq(Tried $token->[4], but text: "$actual_text" !~ /$expected_content/);
                next TOKEN;
            }
        } 
        else {
            if ($actual_text ne $expected_content) {
                push @misses, qq(Tried $token->[4], but text: "$actual_text" ne "$expected_content");
                next TOKEN;
            }
        }

        if ($put_back_when & PUT_BACK_ON_FIND) {
            $parser->unget_token(@tokens);
        }
        return qq(Found $token->[4] followed by text: "$actual_text".);
    }

    if ($put_back_when & PUT_BACK_ON_MISS) {
        $parser->unget_token(@tokens);
    }
    die \@misses;
}

=item failed_test_at()

This method is used internally by the tests to note the filename and line number of the failure.

=cut

sub failed_test_at {
    my (undef, $filename, $line) = caller(1);
    $Test->diag("Failed test ($filename at line $line)");
}

=item has_tag_with_attrs($parser, $tag, $expected_attrs, $name)

This is a test that calls C<tag_with_attrs()> and succeeds when a matching tag is found.

=cut

sub has_tag_with_attrs {
    my ($parser, $tag, $expected_attrs, $name) = @_;

    eval {
        tag_with_attrs($parser, $tag, $expected_attrs, PUT_BACK_ON_MISS);
    };

    if ($@) {
        $Test->ok(0, $name);
        failed_test_at();
        if (@{ $@ }) {
            for my $problem (@{ $@ }) {
                $Test->diag($problem);
            }

            return 0;
        }
        else {
            $Test->diag("Found no $tag elements.");
            return 0;
        }
    }
    else {
        $Test->ok(1, $name);
        return 1;
    }
}

=item no_tag_with_attrs($parser, $tag, $expected_attrs, $name)

This is a test that calls C<tag_with_attrs()> and succeeds when no matching tag is found.

=cut

sub no_tag_with_attrs {
    my ($parser, $tag, $expected_attrs, $name) = @_;

    my $found = eval {
        tag_with_attrs($parser, $tag, $expected_attrs, PUT_BACK_ALWAYS);
    };

    if ($@) {
        $Test->ok(1, $name);
        return 1;
    } 
    else {
        $Test->ok(0, $name);
        failed_test_at();
        $Test->diag($found);
        return 0;
    }
}

=item has_tag_with_content($parser, $tag, $expected_content, $name)

This is a test that calls C<tag_with_content()> and succeeds when a matching tag is found.

=cut

sub has_tag_with_content {
    my ($parser, $tag, $expected_content, $name) = @_;

    eval {
        tag_with_content($parser, $tag, $expected_content, PUT_BACK_ON_MISS);
    };

    if ($@) {
        $Test->ok(0, $name);
        failed_test_at();
        if (@{ $@ }) {
            for my $problem (@{ $@ }) {
                $Test->diag($problem);
            }
            return 0;
        }
        else {
            $Test->diag("Found no $tag elements.");
            return 0;
        }
    }
    else {
        $Test->ok(1, $name);
        return 1;
    }
}

=item $ua = user_agent()

Return the singleton reference to the L<LWP::UserAgent> used by the various HTTP methods of this module.

=cut

my $user_agent;
sub user_agent {
    return $user_agent if defined $user_agent;
    return $user_agent = LWP::UserAgent->new(cookie_jar => {});
}

=item $uri = make_url($rel)

Returns an absolute L<URI> object using the current host:port information and the given relative address, C<$rel>.

=cut

sub make_url {
    my $base_url = URI->new("http://$ENV{TEST_HOSTPORT}");
    my $url      = URI->new_abs(shift, $base_url);
    return $url;
}

=item $response = GET($url, %headers)

Returns an L<HTTP::Response> object for the request at the given relative URL.

=cut

sub GET {
    my $url = make_url(shift);
    my $r   = HTTP::Request::Common::GET($url, @_);
    my $ua  = user_agent();

    return $ua->request($r);
}

=item $response = POST($url, $form_ref, %headers)

=item $response = POST($url, %headers)

Returns an L<HTTP::Response> object for the request at the given relative URL.

=cut

sub POST {
    my $url = make_url(shift);
    my $r   = HTTP::Request::Common::POST($url, @_);
    my $ua  = user_agent();

    return $ua->request($r);
}

=back

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
