package Contentment::Setting;

use strict;
use warnings;

our $VERSION = '0.01';

use Log::Log4perl;
use SPOPS::Initialize;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

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

1

