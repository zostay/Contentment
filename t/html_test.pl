use strict;
use Carp;
use HTML::TokeParser;
use Test::Builder;
my $Test = Test::Builder->new;

use constant NEVER   => 0x00;
use constant ON_FIND => 0x01;
use constant ON_MISS => 0x02;
use constant ON_ALL  => 0x03;

sub parse_html {
    return HTML::TokeParser->new(\$_[0]);
}

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

        if ($put_back_when & ON_FIND) {
            $parser->unget_token(@tokens);
        }
#        $Test->diag(qq(HIT $token->[4]));
        return qq(Found $token->[4].);
    }

    if ($put_back_when & ON_MISS) {
        $parser->unget_token(@tokens);
    }
    die \@misses;
}

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

        if ($put_back_when & ON_FIND) {
            $parser->unget_token(@tokens);
        }
        return qq(Found $token->[4] followed by text: "$actual_text".);
    }

    if ($put_back_when & ON_MISS) {
        $parser->unget_token(@tokens);
    }
    die \@misses;
}

sub failed_test_at {
    my (undef, $filename, $line) = caller(1);
    $Test->diag("Failed test ($filename at line $line)");
}

sub has_tag_with_attrs {
    my ($parser, $tag, $expected_attrs, $name) = @_;

    eval {
        tag_with_attrs($parser, $tag, $expected_attrs, ON_MISS);
    };

    if ($@) {
        $Test->ok(0, $name);
        failed_test_at;
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

sub no_tag_with_attrs {
    my ($parser, $tag, $expected_attrs, $name) = @_;

    my $found = eval {
        tag_with_attrs($parser, $tag, $expected_attrs, ON_ALL);
    };

    if ($@) {
        $Test->ok(1, $name);
        return 1;
    } 
    else {
        $Test->ok(0, $name);
        failed_test_at;
        $Test->diag($found);
        return 0;
    }
}

sub has_tag_with_content {
    my ($parser, $tag, $expected_content, $name) = @_;

    eval {
        tag_with_content($parser, $tag, $expected_content, ON_MISS);
    };

    if ($@) {
        $Test->ok(0, $name);
        failed_test_at;
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

1
