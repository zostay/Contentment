package SPOPSx::Tool::DateTime;

use strict;
use warnings;

use Log::Log4perl qw/ get_logger /;
my $log = get_logger();

our $VERSION = '0.01';

sub ruleset_factory {
	my ($class, $rstab) = @_;
	push @{ $rstab->{post_fetch_action} }, \&convert_to_date;
	push @{ $rstab->{pre_save_action} }, \&convert_to_string;
	push @{ $rstab->{post_save_action} }, \&convert_to_date;
	$log->is_info &&
		$log->info("DateTime ruleset added post_fetch, pre/post_save rules to [$class]");
	return __PACKAGE__;
}

sub _require_format {
	my $class = shift;
	my $format = shift;
	$format =~ /^[\w:]+$/ 
		or die "Bad format package $format for $class.";
	eval "require $format";
	warn "Possible error including $format: $@" if $@;
	$log->is_info &&
		$log->info("DateTime ruleset required $format.");
}

sub convert_to_date {
	my $self = shift;
	my $config = $self->CONFIG;

	while (my ($field, $format) = each %{ $config->{datetime_format} }) {
		defined $self->{$field} or next;

		$log->debug("Converting $self->{$field} to datetime.");

		unless (ref $format) {
			_require_format($config->{class}, $format);
			$config->{datetime_format}{$field} = $format = $format->new;
		}
		
		$self->{$field} = $format->parse_datetime($self->{$field});
	}

	return __PACKAGE__;
}

sub convert_to_string {
	my $self = shift;
	my $config = $self->CONFIG;

	while (my ($field, $format) = each %{ $config->{datetime_format} }) {
		defined $self->{$field} or next;

		$log->debug("Converting $self->{$field} to string.");

		unless (ref $format) {
			_require_format($config->{class}, $format);
			$config->{datetime_format}{$field} = $format = $format->new;
		}
	
		$self->{$field} = $format->format_datetime($self->{$field});
	}

	return __PACKAGE__;
}
1
