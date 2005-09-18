package Contentment::DBI;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Contentment::DBI - This is the base class for all Class::DBI objects in Contentment

=head1 DESCRIPTION

All Contentment objects that use the L<Class::DBI> persistence framework are based from this class.

Prior to version 0.11 of Contentment, SPOPS was the primary persistence framework employed. I chose to switch to Class::DBI because I've always preferred the interface Class::DBI provided, but SPOPS did appear to be the more elegant of the two frameworks. However, after delving deeply into SPOPS, it turns out that Class::DBI seems a bit more flexible (and is certainly better maintained). The other reason is that the last letter "S" is supposed to stand for "Security" but I think it really stands for "Sucky, Slow Security." It could have been reimplemented, but I didn't want to expend the effort required. Besides, application security will work fine for now and using Class::DBI will give me the opportunity to create object-level security according to a fresh scheme.

=cut

my $init = Contentment->global_configuration;
__PACKAGE__->connection(
	$init->{dbi_database},
	$init->{dbi_username},
	$init->{dbi_password},
);

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
