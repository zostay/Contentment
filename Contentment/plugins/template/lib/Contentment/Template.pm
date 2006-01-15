package Contentment::Template;

use strict;
use warnings;

our $VERSION = '0.06';

use Contentment::Template::Provider;
use Template;

=head1 NAME

Contentment::Template - Setup Template Toolkit for use by Contentment

=head1 SYNOPSIS

  use Contentment::Template;

  my %conf = (
      TRIM        => 1,
      INTERPOLATE => 1,
      EVAL_PERL   => 1,
  );

  my $tt = Contentment::Template->new_template(%conf);
  $tt->process(\$template, { foo => 'bar', baz => 'qux' })
      or die $tt->error;

=head1 DESCRIPTION

This is a factory class for constructing Contentment compatible Template Toolkit template parsers. This may be used by your code to provide some custom templating. It was originally created to help facilitate the use of the L<Contentment::Form> module and it's recommended use.

The factory constructs an object of class L<Template> using configuration information pulled from a number of sources. That configuration is merged as follows:

=over

=item Contentment::Plugin::Template settings

The first place the configuration information is loaded from is the Contentment::Plugin::Template settings. This generally holds the defaults.

=item %conf argument

The C<%conf> argument passed to the C<new_template()> method then contributes and overrides the values set so far.

=item "Contentment::Template::configuration" hook

Each of these hook handlers is called and passed a reference to the current configuration. These hooks are then given the opportunity to modify the configuration.

=item LOAD_TEMPLATES

The "LOAD_TEMPLATES" option is set to an array containing only a reference to L<Contentment::Template::Provider>.

=item OUTPUT

The "OUTPUT" option is always set to the C<STDOUT> file handler.

=back

The last two bit sthere are always set and cannot be changed. This may change in the future.

=cut

sub template_configuration {
	# Base the configuration on Contentment::Plugins::Template->configuration
	my $conf = Contentment::Setting->instance->{'Contentment::Plugin::Template'}{'configuration'};
	my %conf = %{ $conf || {} };
	my $iter;

	# Allow handlers to modify any part of the configuration with the
	# Contentment::FileType::Template::configuration hook.
	Contentment::Hooks->call('Contentment::FileType::Template::configuration',
		\%conf,
	);

#    use Template::Constants qw/ DEBUG_ALL /;
#    $conf{DEBUG} = DEBUG_ALL;

	# Add Contentment::Template::Provider as one of the guys responsible for
	# fetch()-ing templates
	$conf{LOAD_TEMPLATES} = [
		Contentment::Template::Provider->new,
	];

	# Output is ALWAYS to STDOUT. No meddling kids!
	$conf{OUTPUT} = \*STDOUT;

	return \%conf;
}

my $template;
sub new_template {
	return $template if $template;

	Contentment::Log->debug("Creating a new template singleton.");

	my $conf = Contentment::Template->template_configuration;
	return $template = Template->new($conf);
}

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp E<lt>hanenkamp@cpan.orgE<gt>.  All 
Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut

1
