package Contentment::Setting;

use strict;
use warnings;

our $VERSION = '0.01';

use Log::Log4perl;
use SPOPS::Initialize;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::Setting - A basic module for storing database settings

=head1 DESCRIPTION

Not sure if this module is sticking around yet. I thought I was going to use it for a couple things, but then didn't. So, no docs until I'm sure it sticks...

=cut

my %spops = (
	setting => {
		class             => 'Contentment::Setting',
		isa               => [ qw/ Contentment::SPOPS / ],
		rules_from        => [ qw/ SPOPSx::Tool::HashField / ],
		base_table        => 'setting',
		field             => [ qw/ namespace data / ],
		id_field          => 'namespace',
		hash_fields       => [ 'data' ],
		no_update         => [ qw/ setting_id namespace / ],
		no_security       => 1,
	},
);

SPOPS::Initialize->process({ config => \%spops });

__PACKAGE__->_create_table('MySQL', 'setting', q(
	CREATE TABLE setting (
		namespace     CHAR(255),
		data          TEXT,
		PRIMARY KEY (namespace));
));

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1

