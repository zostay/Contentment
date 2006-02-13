package Contentment::Theme;

use strict;
use warnings;

our $VERSION = '0.10';

use Contentment::Log;
use Contentment::Response;
use Contentment::Setting;
use Contentment::VFS;
use File::Spec;

=head1 NAME

Contentment::Theme - Contentment plugin for adding themes to content

=head1 SYNOPSIS

  $context->theme('master', \%arguments);

=head1 DESCRIPTION

The theme plugin provides a simple theming system. Basically, the L</"SYNOPSIS"> says it all. To take some data and theme that data, simply call:

  $context->theme('master', \%arguments);

The "master" is the name of the master template to apply to the arguments. The arguments will be passed to the theme in the way that arguments are normally passed to the filetype of the master template.

=head2 HOW THEMES WORK

If you want to create a theme, you need to understand how theming works. Of course, you probably want to have a general idea if you are using them too.

Essentially, the themes are loaded via the VFS path named something like this:

  /themes/<theme>/<kind>/<master>

Each of the variables E<lt>themeE<gt>, E<lt>kindE<gt>, and E<lt>masterE<gt> translate into a piece of the path to the theme template. Other theming assets may be found under the F</themes> directory as well.

The E<lt>themeE<gt> variable is currently set using the C<default_theme> variable of the C<Contentment::Plugin::Settings> setting. However, if a template is requested that cannot be found in a theme, the theme named F<default> is also searched as a fallback.

The E<lt>kindE<gt> variable is the kind of master to pull from. This allows for documents to be served in multiple formats. In general, you just need to fill the F<text/html> subdirectories (e.g., F</themes/default/text/html>).

The E<lt>masterE<gt> variable is the name of the actual template file to use. It may also include additional subdirectories. For example, the Form plugin employs the use of masters like F<form/Form> and F<form/Submit> for the various controls. The top-level or page-level document is generally called F<top>.

The templates themselves are generally created for particular uses. The uses are generally defined by each of the plugins. Eventually the manual will show the primary templates and the arguments they are typically passed.

Basically, all theme data is stored under the F</themes> directory of the VFS. Inside that directory are subdirectories containing one or more themes. There must always be a theme named F<default> inside of the F</themes> directory that is used as a fallback.

Inside of each theme directory are directories for each destination file type that a theme should be applied to and any extra files and directories used by the theme. So far, the convention has been to create a directory named F<images> to hold the graphics and photos, F<styles> to hold stylesheets, and the rest are actual themes. However, the theme designer may arrange her files in whichever way is convenient.

Since the typical final file type uses the MIME-type "text/html", the theme directory for HTML files is usually a nested directory, F<text/html>. Once inside the file type directory, the theme master is used to render the theme. The theme master can be anything. By default the top-level or page theme is called F<top>. Thus, altogether, the path to a theme master is:

=head2 CONTEXT

This class adds the following methods to the context:

=over

=item $context->theme($master, \%args)

This applies the requested theme master, C<$master>, using the current file type stored in C<Contentment::Response->top_kind> and the theme set in the "default_theme" key of the "Contentment::Plugin::Theme" setting.

The special parameter "theme_dir" is passed to every template during generation to let it know of the template's base directory. This is relative to the base URL, so you may need to include a reference to the site variable "base_url" if you need an absolute base address for the client:

  my $site = Contentment::Site->current_site;
  print $site->base_url;

or using a Template Toolkit template:

  [% USE Site %]
  [% Site.base_url %]

=cut

sub Contentment::Context::theme {
    my $context = shift;
    my $class   = __PACKAGE__;
    my $master  = shift;
    my $args    = shift || {};

    # Master must be given
    if (!defined($master)) {
        Contentment::Exception->throw(
            message => 'theme(): called with an undefined master.',
        );
    }

    # Lookup the theme to use, make sure we fallback on "default"
    my $settings = $context->settings;
    my @themes
        = ($settings->{'Contentment::Plugin::Theme'}{'default_theme'})
            || ();
    push @themes, 'default' unless @themes && $themes[0] eq 'default';

    # Try "default" after the regular theme
    THEME:
    for my $theme (@themes) {
        # See if there's a theme for this kind
        my $kind       = Contentment->context->response->top_kind || '';
        my $theme_dir  = "themes/$theme/";
        my $theme_path = "/$theme_dir$kind/$master";
        my $gen = Contentment->context->response->resolve($theme_path);

        # Did the resolver find nothing or experience an error?
        if ($gen->get_property('error')) {

            # Nope, no theme. Skip it.
            Contentment::Log->debug(q(No theme found for kind '%s'), [$kind]);
            next THEME;
        } 

        Contentment::Log->debug(
            'Theme found for kind "%s", generating %s', 
            [$kind,$gen]
        );
        $gen->generate(
            %$args,
            theme_dir => $theme_dir,
        );
    }

    # If we didn't theme above and exit, we need to at least push the input
    # over to output
    print <STDIN>;
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::Theme::upgrade

This handler is for the "Contentment::upgrade" hook and is responsible for making sure any changes to "default_theme" or "default_template" are transferred during upgrades.

=cut

sub upgrade {
    my $context      = shift;
    my $old_settings = shift;
    my $new_settings = shift;

    $new_settings->{default_theme}    = $old_settings->{default_theme};
    $new_settings->{default_template} = $old_settings->{default_template};
}

=item Contentment::Theme::apply_theme

Handles the "Contentment::Response::filter" hook by attempting to wrap the generated output with a theme, or leaving the output as is if there is no matching theme handler.

=cut

sub apply_theme {
    my $context = shift;
    # Lookup the template to use
    my $settings = $context->settings;
    my $template
        = $settings->{'Contentment::Plugin::Theme'}{'default_template'}
            || 'top';
    $context->theme($template);
}

=item Contentment::Theme::begin

Handles the "Contentment::begin" hook. When run, it notifies the VFS to add the plugins "docs" folders layer.

=cut

sub begin {
    my $context = shift;

	Contentment::Log->debug("Calling hook handler Contentment::Theme::begin");
	my $vfs = $context->vfs;
	my $settings = $context->settings;
	my $plugin_data = $settings->{'Contentment::Plugin::Theme'};
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
