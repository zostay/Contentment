package Contentment::Setting;

use strict;
use warnings;

our $VERSION = '0.03';

use Log::Log4perl;
use SPOPS::Initialize;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::Setting - A Contentment plugin for storing configuration

=head1 DESCRIPTION

This module is required by the Contentment core and is used to store settings and configuration information in the database.

=cut

my %spops = (
	setting => {
		class             => 'Contentment::Setting',
		isa               => [ qw/ Contentment::SPOPS / ],
		rules_from        => [ qw/ SPOPSx::Tool::YAML / ],
		base_table        => 'setting',
		field             => [ qw/ namespace data / ],
		id_field          => 'namespace',
		yaml_fields       => [ 'data' ],
		no_update         => [ qw/ setting_id namespace / ],
		no_security       => 1,
	},
);

SPOPS::Initialize->process({ config => \%spops });

sub install {
	my $dbh = __PACKAGE__->global_database_handle;
	$dbh->do(q(
		CREATE TABLE setting (
			namespace		CHAR(255),
			data			TEXT,
			PRIMARY KEY (namespace));
	));
}

sub upgrade { }

sub remove {
	my $dbh = __PACKAGE__->global_database_handle;
	$dbh->do(q(
		DROP TABLE setting;
	));
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1

