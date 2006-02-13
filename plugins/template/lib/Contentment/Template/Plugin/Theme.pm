package Contentment::Template::Plugin::Theme;

use strict;
use warnings;

our $VERSION = '0.11';

use base qw/ Contentment::Theme Template::Plugin /;

use IO::NestedCapture qw( capture_out );

sub new { bless {}, $_[0] }

sub theme {
    my $self   = shift;
    my $master = shift;
    my $args   = shift || {};

#    use Data::Dumper;
#    print STDERR Dumper($master, $args);

    capture_out {
        Contentment->context->theme($master, $args);
    };

    my $fh = IO::NestedCapture->get_last_out;
    return join '', <$fh>;
}

1
