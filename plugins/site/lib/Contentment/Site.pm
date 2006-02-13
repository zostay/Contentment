package Contentment::Site;

use strict;
use warnings;

our $VERSION = '0.03';

use base 'Oryx::Class';

use URI;

=head1 NAME

Contentment::Site - A plugin for managing site information

=head1 SYNOPSIS

  my $site = $context->current_site;

  my $base_url = $site->base_url;
  print qq(<a href="$base_url/my/absolute/link.html">Absolute Link</a>\n);

=head1 DESCRIPTION

The L<Contentment::Site> class is used to store site information. Each request recieved by Contentment is matched against each site record to find a match. If no match is found, the default site information is assumed. Based upon this information, various plugins can make decisions to make a given site appear or behave differently from the main site.

Currently, sites are differentiated by very primitive means. Additional means may be added in the future. At this time, each site is specified by four parameters: scheme, server name, server port, and root path. An additional field also uniquely identifies each site called the site name, which is just a mnemonic identifier. Each site has other configuration information associated with it, which is stored via the L<Contentment::Setting> table.

It is possible for the current request to match on all three scheme, server name, and server port and match more than one root path. For example, given the request:

  http://www.contentment.org/foo/bar.html

and two different site records with the following base URLs:

  http://www.contentment.org/
  http://www.contentment.org/foo/

in this case, the current request essentially matches both. In the case of this occurrence, the site record with the longest matching root path will be given preference.

The site record with site name "default" is special. This is the site that will be used as the current site if no site matches directly.

=cut

our $schema = {
    attributes => [ {
        name => 'scheme',
        type => 'String',
    }, {
        name => 'server_name',
        type => 'String',
    }, {
        name => 'server_port',
        type => 'Integer',
    }, {
        name => 'root_path',
        type => 'String',
    }, {
        name => 'site_name',
        type => 'String',
    } ],
    associations => [ {
        role  => 'settings_record',
        type  => 'Reference',
        class => 'Contentment::Setting',
    } ],
};

=head2 FIELDS

Each instance of L<Contentment::Site> has the following fields:

=over

=item $scheme = $site-E<gt>scheme

=item $site-E<gt>scheme($new_scheme)

This is the scheme the site matches. Only values of "http" and "https" make sense. This value must be set.

=item $server_name = $site-E<gt>server_name

=item $site-E<gt>server_name($new_server_name)

This is the server name that the site matches. This value must be set to a fully-qualified hostname or string representation of an IP address. (Obviously, the former should be preferred.)

See L</"BUGS"> about a possible caveat involving host names without periods (i.e., "localhost").

=item $server_port = $site-E<gt>server_port

=item $site-E<gt>server_port($new_server_port)

This is the port number of the site. This must be set. Typically, the value will be "80" if the scheme is "http" and "443" if the scheme is "https", but it might be something completely different in either case.

=item $root_path = $site-E<gt>root_path

=item $site-E<gt>root_path($new_root_path)

This is the full path to the root of the server. This must be given even if the root path is just the root path of the server---in which case it should be given as "/", and B<not> the empty string "". The root path should always end in a trailing slash.

=item $uri = $site-E<gt>base_url

=item $site-E<gt>base_url($new_uri)

=item $uri = $site-E<gt>base_uri

=item $site-E<gt>base_uri($new_uri)

This method returns a L<URI> object set to contain the information returned by C<scheme()>, C<server_name()>, C<server_port()>, and C<root_path()>. The L<URI> object will be normalized via the C<canonical()> method.

If the the mutator form of the method is used to set a new URI (C<$new_uri>), the URI may be given as either a string or URI object. If given as a string, it will be passed to L<URI>'s constructor. Each of the other fields will be updated from the L<URI> object given.

=cut

sub base_uri {
    my $self = shift;
    my $uri  = shift;

    # Are they using the mutator?
    if (defined $uri) {

        # Did they give us a plain string?
        if (!ref $uri) {
            $uri = URI->new($uri);
        }

        $self->scheme($uri->scheme);
        $self->server_name($uri->host);
        $self->server_port($uri->port);
        $self->root_path($uri->path);
    }

    # Just the accessor then
    else {
        $uri = URI->new;
        $uri->scheme($self->scheme);
        $uri->host($self->server_name);
        $uri->port($self->server_port);
        $uri->path($self->root_path);
    }

    return $uri->canonical;
}

# Alias base_url to base_uri
*base_url = *base_uri;

=item $site_name = $site-E<gt>site_name

=item $site-E<gt>site_name($new_site_name)

This is a mnemonic site name that is mostly useful for the management of sites. The site named "default" is special and is used when no other site matches. There must always be at least one site with the site name of "default".

=item $settings = $site-E<gt>settings

=item $site-E<gt>settings($new_settings)

This holds the rest of the settings for the site. This field actually returns the value of the setting named "Contentment::Site::I<site_name>", where I<site_name> is the value returned by C<site_name()>. The value returned is a reference to a hash. 

If you need to update the settings, you must use the mutator method here to make those settings stick. The settings will be immediately updated, but not committed. 

=cut

sub settings {
    my $self     = shift;
    my $settings = shift;

    if (defined $settings) {
        my $setting = $self->settings_record;
        $setting->setting_value($settings);
        $setting->update;
    }

    return $self->settings_record->setting_value;
}

sub update {
    my $self = shift;

    if ($self->server_name !~ /\./) {
        $self->server_name($self->server_name.'.local');
    }

    return $self->SUPER::update(@_);
}



sub create {
    my $class = shift;
    my $proto = shift;

    my $self;

    # Handle inheritance correctly
    if ($class eq __PACKAGE__) {

        # See BUGS for details
        if ($proto->{server_name} !~ /\./) {
            $proto->{server_name} .= '.local';
        }

        # Create it; create and add the settings object
        $self = $class->SUPER::create($proto);
        my $setting = Contentment::Setting->create({
            setting_name  => 'Contentment::Site::'.$self->site_name,
            setting_value => {},
        });
        $self->settings_record($setting);
        $self->update;
    }

    else {
        $self = $class->SUPER::create($proto);
    }

    return $self;
}

=back

=head2 METHODS

Each instance of L<Contentment::Site> is an L<Oryx> object, with all the methods there and the methods described in the L</"FIELDS"> section. In addition, the following methods are defined.

=over

=item $site = Contentment::Site-E<gt>current_site

This fetches the site record that either matches the current request or fetches the site record with the site name "default".

=cut

sub current_site {
    my $self = shift;
    
    # Get information about the current request
    my $q           = Contentment->context->cgi;
    my $scheme      = $q->https ? 'https' : 'http';
    my $server_name = $q->server_name;
    my $server_port = $q->server_port;
    my $path        = $q->path_info;

    # See BUGS for details
    if ($server_name !~ /\./) {
        $server_name .= '.local';
    }

    # Find all sites that match based upon scheme, server name and port
    my @sites = Contentment::Site->search({
        scheme      => $scheme,
        server_name => $server_name,
        server_port => $server_port,
    });

    my $best_match;
    my $match_length = 0;

    # Loop through the sites found and see if we can match the request path with
    # the root path of one or more of the sites.
    for my $site (@sites) {
        my $root_path = quotemeta $site->root_path;
        my $path_len  = length $site->root_path;

        # Don't both checking if the match length is shorter than a known match,
        # since it cannot be the optimum.
        if ($path_len > $match_length && $path =~ /^$root_path/) {
            $match_length = $path_len;
            $best_match   = $site;
        }
    }

    # Return if a match has been found. Otherwise, return the default.
    return defined $best_match ? $best_match
                               : (Contentment::Site
                                    ->search({ site_name => 'default' }))[0];
}

=back

=head2 CONTEXT

This class adds the following methods to the context:

=over

=item $site = $context-E<gt>current_site

Returns a reference to the L<Contentment::Site> instance for the current site.

=cut

sub Contentment::Context::current_site {
    my $context = shift;
    return Contentment::Site->current_site;
}

=item @sites = $context-E<gt>sites(\%params)

Returns a list of site instances. If the optional C<%params> hash is not given or is empty, all sites will be returned. Otherwise, this method returns the sites found by calling the C<search()> method, like so:

  my @sites = Contentment::Site->search(\%params);

=cut

sub Contentment::Context::sites {
    my $context = shift;
    return Contentment::Site->search(@_);
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::Site::install

This handles the "Contentment::install" hook and installs the database table.

=cut

sub install {
    __PACKAGE__->storage->deployClass(__PACKAGE__);
}

=item Contentment::Site::begin

This handles the "Contentment::Request::begin" hook. It checks to see if a default site has already been created (by looking to see if the "default_created" setting is set in the "Contentment::Plugin::Site" settings). Creates a default site based upon the information given in the current request. It will check for a global configuration setting named "initial_site_root_path" to fill in the root path. If none is set, it will assume "/" (which may be bad, but I can't think of a better solution at this time).

=cut

sub begin {
    my $ctx = shift;
    my $q   = $ctx->cgi;

    my $settings        = $ctx->settings;
    my $plugin_settings = $settings->{'Contentment::Plugin::Site'};

    # We've not created it yet
    if (!$plugin_settings->{'default_created'}) {
        my $initial_root_path = Contentment->global_configuration->{'initial_site_root_path'} || '/';
        my $site = Contentment::Site->create({
            scheme      => $q->https ? 'https' : 'http',
            server_name => $q->server_name,
            server_port => $q->server_port,
            root_path   => $initial_root_path,
            site_name   => 'default',
        });

        Contentment::Log->info(
            'Created default site record "%s": %s',
            [$site->site_name, $site->base_url]
        );

        # Make sure we don't do this again
        $plugin_settings->{'default_created'} = 1;
        $settings->{'Contentment::Plugin::Site'} = $plugin_settings;

        $site->commit;
    }
}

=back

=head1 BUGS

I'm not sure where this comes from, but LWP doesn't handle cookies where the hostname does not contain a period. Instead, if it encounters such a host, it automatically appends ".local" to the hostname. 

Since the test suite relies upon "localhost" (a hostname without a period) and cookies need to be tested, upon creation or update this class will automatically add ".local" to the host part of any site URI that does not contain a period. Whether this is a good idea or bad one, I don't know, but it solves the problem at this time.

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
