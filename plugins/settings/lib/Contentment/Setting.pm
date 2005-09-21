package Contentment::Setting;

use strict;
use warnings;

our $VERSION = '0.06';

use base 'Contentment::DBI';

=head1 NAME

Contentment::Setting - A Contentment plugin for storing configuration

=head1 DESCRIPTION

This module is required by the Contentment core and is used to store settings and configuration information in the database.

=cut

__PACKAGE__->table('setting');
__PACKAGE__->columns(Primary => 'setting_name');
__PACKAGE__->columns(Essential => qw/ setting_name setting_value /);

__PACKAGE__->column_definitions([
	[ setting_name  => 'varchar(150)', 'not null' ],
	[ setting_value => 'text', 'null' ],
]);

sub installed {
	my $dbh = __PACKAGE__->db_Main;
	my $test = grep /\bsetting\b/, $dbh->tables(undef, undef, 'setting');
	return $test;
}

sub install {
	__PACKAGE__->create_table;
}

sub remove {
	__PACKAGE__->drop_table;
}

=over

=item $settings = Contentment::Setting-E<gt>instance

Returns a reference to a hash containing all the settings. Settings are permanently saved to the database when changed.

This hash can be used to store most complex types. It uses L<YAML> to encode all the values, which can encode just about anything.

However, there are a few caveats to be creaful about:

=over

=item *

References to blessed items or types other than scalars, hashes, or arrays might not store and load again quite as you expect. In particular, objects can be blessed into classes that aren't even loaded.

=item *

Be careful modifying deep parts of the code without tellings the settings. For example:

  my $settings = Contentment::Setting->instance;
  my %hash = ( foo => 1, bar => 2 );

  # Works great!
  $settings->{blah} = \%hash;

  $hash{baz} = 3;

  # Bad stuff! Outputs: foo, bar
  # $settings doesn't know about baz!
  print(join(', ', keys %$settings),"\n");

  # Make sure you always notify the hash of deep changes:
  $settings->{blah} = \%hash;

=back

=cut

sub instance {
	my $class = shift;
	tie my %hash, 'Contentment::Setting::Tie';
	return \%hash;
}

package Contentment::Setting::Tie;

use YAML;

sub TIEHASH {
	my $class = shift;
	return bless {}, $class;
}

sub FETCH {
	my $self = shift;
	my $key  = shift;

	my $setting = Contentment::Setting->retrieve($key);
	return $setting ? Load($setting->setting_value) : undef;
}

sub STORE {
	my $self  = shift;
	my $key   = shift;
	my $value = shift;

	my $setting = Contentment::Setting->retrieve($key);
	if ($setting) {
		$setting->setting_value(Dump($value));
		$setting->update;
	} else {
		$setting = Contentment::Setting->create({
			setting_name  => $key,
			setting_value => Dump($value),
		});
	}
	return $value;
}

sub DELETE {
	my $self = shift;
	my $key  = shift;

	my $setting = Contentment::Setting->retrieve($key);
	if ($setting) {
		my $value = Load($setting->setting_value);
		$setting->delete;
		return $value;
	} else {
		return undef;
	}
}

sub CLEAR { 
	# There's no way in hell I'm letting someone do something this stupid, this
	# easily. Forget it.
	die "Have you lost your mind? I will not help you delete all settings.";
}

sub EXISTS {
	my $self = shift;
	my $key  = shift;

	my $setting = Contentment::Setting->retrieve($key);
	return $setting ? 1 : '';
}

sub FIRSTKEY {
	my $self = shift;

	$self->{iter} = Contentment::Setting->retrieve_all;
	if (my $setting = $self->{iter}->next) {
		return $setting->setting_name;
	} else {
		return undef;
	}
}

sub NEXTKEY {
	my $self = shift;

	if (my $setting = $self->{iter}->next) {
		return $setting->setting_name;
	} else {
		return undef;
	}
}

sub SCALAR {
	my $self = shift;
	return Contentment::Setting->count_all;
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
