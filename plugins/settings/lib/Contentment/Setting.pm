package Contentment::Setting;

use strict;
use warnings;

our $VERSION = '0.04';

use Contentment::ClassDBI;
use YAML;

=head1 NAME

Contentment::Setting - A Contentment plugin for storing configuration

=head1 DESCRIPTION

This module is required by the Contentment core and is used to store settings and configuration information in the database.

=cut

__PACKAGE__->table('setting');
__PACKAGE__->columns(All => qw/ namespace data /);
__PACKAGE__->columns(Primary => 'namespace');

__PACKAGE__->has_a(
	data    => 'HASH',
	inflate => sub { Load(shift) },
	deflate => sub { Dump(shift) },
);

__PACKAGE__->column_definitions([
	[ namespace => 'varchar(50)', 'not null' ],
	[ data      => 'text', 'not null' ],
]);

sub installed {
	my $dbh = __PACKAGE__->global_database_handler;
	my $test = grep /\bsetting\b/, $dbh->tables(undef, undef, 'setting')
	return $test;
}

sub install {
	__PACKAGE__->create_table;
}

sub remove {
	__PACKAGE__->drop_table;
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
