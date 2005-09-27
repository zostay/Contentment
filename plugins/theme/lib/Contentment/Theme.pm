package Contentment::Theme;

use strict;
use warnings;

our $VERSION = '0.01';

use Contentment::Log;
use Contentment::Response;
use Contentment::Setting;
use Contentment::VFS;
use File::Spec;

=head1 NAME

Contentment::Theme - Contentment plugin for adding themes to content

=head1 DESCRIPTION

=head2 HOOK HANDLERS

=over

=item Contentment::Theme::theme

Handles the "Contentment::Response::end" hook by attempting to wrap the generated output with a theme, or leaving the output as is if there is no matching theme handler.

=cut

sub theme {
	my $kind = Contentment::Response->top_kind;
	my $comp = Contentment::Response->resolve(
		"/themes/default/$kind/top"
	);

	if ($comp) {
		Contentment::Log->debug("Theme found for kind '%s', generating %s", [$kind,$comp]);
		$comp->generate;
	} else {
		Contentment::Log->debug("No theme found for kind '%s'", [$kind]);
		print <STDIN>;
	}
}

=item Contentment::Theme::begin

Handles the "Contentment::begin" hook. When run, it notifies the VFS to add the plugins "docs" folders layer.

=cut

sub begin {
	Contentment::Log->debug("Calling hook handler Contentment::Theme::begin");
	my $vfs = Contentment::VFS->instance;
	my $setting = Contentment::Setting->instance;
	my $plugin_data = $setting->{'Contentment::Plugin::Theme'};
	my $docs = File::Spec->catdir($plugin_data->{plugin_dir}, 'docs');
	$vfs->add_layer(-1, [ 'Real', 'root' => $docs ]);
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as Perl itself.

=cut

1
