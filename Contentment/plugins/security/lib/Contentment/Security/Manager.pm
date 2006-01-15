package Contentment::Security::Manager;

use strict;
use warnings;

our $VERSION = 0.07;

use Contentment::Hooks;
use Contentment::Security::Principal;
use Contentment::Security::Profile::Persistent;
use Contentment::Security::Profile::Scratch;
use Contentment::Security::Role;
use Digest;

use base 'Class::Singleton';

=head1 NAME

Contentment::Security::Manager - Interface implemented by Contentment security managers

=head1 DESCRIPTION

The security manager is a singleton object used by the L<Contentment::Security> class to determine the security permissions to grant the current request. This module, C<Contentment::Security::Manager>, both documents the interface and provides a very simple implementation. This implementation will be used if no other is provided.

=head2 INTERFACE

The security manager interface must implement the following method:

=over

=item $secman = Contentment::Security::Manager-E<gt>instance

Return an instance of the security manager. This is named C<instance> because it is generally assumed that this object will be a single (see L<Class::Singleton>). It doesn't really have to be a singleton, but this method will still only be called once.

=item $principal = $secman-E<gt>get_principal

Return the C<Contentment::Security::Principal> to associate with the request.

=item $principal = $secman-E<gt>lookup_principal($username)

Return a C<Contentment::Security::Principal> matching the given username, C<$username>, or return C<undef> if no match can be found.

=back

If you create a security manager, you need to modify the value of "security_manager" in the "Contentment::Plugin::Security" settings.

=head2 IMPLEMENTATION

The built-in security system is simple. It uses L<Contentment::Security::Profile::Persistent> to store usernames with passwords for authenticated users. It uses L<Contentment::Security::Profile::Scratch> to store the rest. It will create a generic principal if no authentication has taken place (i.e., no principal has already been recorded in the L<Contentment::Session>).

Authentication may be performed using the C<login> method. The C<logout> method will return the session to an anonymous principal.

Any authenticated principal will always have at least two roles: "everybody" and "authenticated". Any anonymous principal will always have only two roles: "everybody" and "anonymous".

=cut

sub _new_instance {
    my $class = shift;

    Contentment::Hooks->register(
        hook => 'Contentment::Session::begin',
        code => \&Contentment::Security::Manager::begin,
    );

    Contentment::Hooks->register(
        hook => 'Contentment::Session::end',
        code => \&Contentment::Security::Manager::end,
    );

   return bless {}, $class;
}

# XXX The result of this method should probably be cached since this is pretty
# costly.
sub get_principal {
    my $self = shift;

    # Find the principal, if possible
    my $principal 
        = Contentment::Session->instance
            ->{'Contentment::Security::Manager::principal'};

    # If no principal, create an anonymous one
    unless ($principal) {
        $principal = Contentment::Security::Principal->new;
        $principal->type('anonymous');
        $principal->profile(
            Contentment::Security::Profile::Scratch->new
        );

        # Store the principal in the session
        Contentment::Session->instance
            ->{'Contentment::Security::Manager::principal'}
                = $principal;
    } 
    
    # Refresh roles and permissions
    $self->_update_roles($principal);
    $principal->update_permissions;

    return $principal;
}

sub lookup_principal {
    my $self     = shift;
    my $username = shift;

    # See if we can find a matching user
    my ($profile) = Contentment::Security::Profile::Persistent->search({
        username => $username,
    });

    # Load the user's data if found to create a principal to return
    my $principal = undef;
    if ($profile) {
        $principal = Contentment::Security::Principal->new;
        $principal->type('authenticated');
        $principal->profile($profile);
        $self->_update_roles($principal);
        $principal->update_permissions($principal);
    }

    # Return the principal found or undef
    return $principal;
}

# This method will make sure that roles are reloaded from the database with
# every access---which could mean that the role set can change mid-response.
sub _update_roles {
    my $self      = shift;
    my $principal = shift;

    # Load the everybody role
    my ($everybody_role) = Contentment::Security::Role->search({
        title => 'Everybody',
    });

    # This is a special role, it shouldn't be deleted.
    defined $everybody_role
        or Contentment::Log->error('Special role "Everybody" is missing!');

    # Is this an "authenticated" principle or "anonymous"?
    if ($principal->type eq 'authenticated') {

        # Load the authenticated role
        my ($authenticated_role) = Contentment::Security::Role->search({
            title => 'Authenticated',
        });
    
        # This is a special role, it shouldn't be deleted.
        defined $authenticated_role
            or Contentment::Log->error(
                'Special role "Authenticated" is missing!'
            );

        # The principal gets the roles in the profile, Authenticated, and
        # Everybody
        $principal->roles([
            @{ $principal->profile->roles },
            (defined $authenticated_role ? $authenticated_role : ()),
            (defined $everybody_role     ? $everybody_role     : ()),
        ]);
    } 
    else {

        # Load the anonymous role
        my ($anonymous_role) = Contentment::Security::Role->search({
            title => 'Anonymous',
        });
        
        # This is a special role, it shouldn't be deleted.
        defined $anonymous_role
            or Contentment::Log->error(
                'Special role "Anonymous" is missing!'
            );
        
        # The principal gets the Anonymous and Everybody roles.
        $principal->roles([
            (defined $anonymous_role ? $anonymous_role : ()),
            (defined $everybody_role ? $everybody_role : ()),
        ]);
    }
}

=over

=item $test = $secman-E<gt>login($username, $password)

On success, this method will return a true value and C<get_principal> may be used to fetch the newly authenticated principal. On failure, this value returns false and C<get_principal> will continue to return whatever value was there before.

=cut

sub login {
    my $self     = shift;
    my $username = shift;
    my $password = shift;

    my ($profile) = Contentment::Security::Profile::Persistent->search({
        username => $username,
        password => $password,
    });

    if ($profile) {
        # Make sure we update the state of any old principal we need to
        my $old_principal = $self->get_principal;
        if ($old_principal->type eq 'authenticated') {
            $old_principal->profile->update;
            $old_principal->profile->commit;
            Contentment::Log->info('LOGOUT by %s', [$old_principal->username]);
        }

        # Be sure and save their anonymous profile if they had one
        else {
            $self->_save_anonymous_profile($old_principal);
        }

        # Okay, now load the new principal
        my $principal = Contentment::Security::Principal->new;
        $principal->type('authenticated');
        $principal->profile($profile);
        $self->_update_roles($principal);
        $principal->update_permissions;

        # Save it to the session so we remember the login
        Contentment::Session->instance
            ->{'Contentment::Security::Manager::principal'}
                = $principal;

        # Finally, check to make sure they may login.
        my $may_login = Contentment::Security->has_permission(
            'Contentment::Security::Manager::login');
        unless ($may_login) {
            delete Contentment::Session->instance
                ->{'Contentment::Security::Manager::principal'};
            Contentment::Log->info(
                'LOGIN FAILED by %s: does not have "login" permission',
                [$username]
            );
            return '';
        }

        # Return success
        Contentment::Log->info('LOGIN SUCCESS by %s', [$username]);
        return 1;
    } 
    
    # Password is not correct for user.
    else {
        # Return failure
        Contentment::Log->info(
            'LOGIN FAILED by %s: incorrect username/password', [$username]);
        return '';
    }
}

=item $secman-E<gt>logout

This method replaces the principal currently stored in the session with an anonymous principal.

=cut

sub logout {
    my $self = shift;

    # Make sure to save the old princpal's state first
    my $old_principal = $self->get_principal;
    if ($old_principal->type eq 'authenticated') {
        $old_principal->profile->update;
        $old_principal->profile->commit;
        Contentment::Log->info("LOGOUT by %s", [$old_principal->username]);
    }

    # Create a new anonymous principal
    my $principal = Contentment::Security::Principal->new;
    $principal->type('anonymous');
    $principal->profile(Contentment::Security::Profile::Scratch->new);

    # Load their anonymous profile in case they have one
    $self->_load_anonymous_profile;

    # Update their roles and permissions
    $self->_update_roles($principal);
    $principal->update_permissions;

    # Save the anonymous principal to the session to overwrite any old login
    # information
    Contentment::Session->instance
        ->{'Contentment::Security::Manager::principal'}
            = $principal;
}

sub _save_anonymous_profile {
    my $self      = shift;
    my $principal = shift;

    if ($principal->full_name || $principal->email_address 
            || $principal->web_site) {

        # Save these three fields with a colon as separated (and escape any
        # colons
        my @fields = (
            $principal->username || 'Anonymous',
            $principal->full_name || '',
            $principal->email_address || '',
            $principal->web_site || '',
        );

        # XXX Add a hook to allow for additional profile storage?

        # Save the data into a cookie
        # XXX The expiration on this cookie should be configurable.
        my $q = Contentment::Request->cgi;
        my $cookie = $q->cookie(
            -name    => 'ANONPROFILE',
            -domain  => Contentment::Site->current_site->base_url->host,
            -value   => \@fields,
            -expires => '+30d');
        push @{ Contentment::Response->header->{'-cookie'} }, $cookie;
    }
}

sub _load_anonymous_profile {
    my $self      = shift;
    my $principal = shift;

    # Check to see if there is a special anonymous profile cookie
    my $q = Contentment::Request->cgi;
    my @profile = $q->cookie('ANONPROFILE');

    # If so, load that sucker up
    if (@profile) {
        Contentment::Log->debug(
            'Refreshing scratch profile for anonymous user.',
        );
        my $principal = $self->get_principal;

        # Set the data stored in the cookie
        my ($username, $full_name, $email_address, $web_site) = @profile;
        $principal->profile->username($username);
        $principal->profile->full_name($full_name);
        $principal->profile->email_address($email_address);
        $principal->profile->web_site($web_site);

        # XXX Add a hook to allow further anonymous profile retrieval?
    }

    # If not, don't worry about it. It's just another blank profile.
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::Security::Manager::begin

This hook handler is for the "Contentment::Session::begin" hook. The handler loads the current principal.

=cut

# XXX Is this really necessary?
sub begin {
    my $principal = Contentment::Security->get_principal;

    Contentment::Log->debug('Running Contentment::Security::Manager::begin.');
    
    # Since the YAML serialization will lose ties, reload the profile from
    # the database
    if ($principal->type eq 'authenticated') {
        Contentment::Log->debug(
            'Refreshing profile information for user %s.',
            [$principal->username]
        );
        my ($profile) = Contentment::Security::Profile::Persistent->search({
            username => $principal->username,
        });
        $principal->profile($profile);
    }

    # Load their anonymous profile if they have one
    else {
        Contentment::Security::Manager->instance->_load_anonymous_profile(
            Contentment::Security->get_principal,
        );
    }
}

=item Contentment::Security::Manager::end

This hook handler is for the "Contentment::Session::end" hook. The handler saves the current principal.

=cut

sub end {
    my $principal = Contentment::Security->get_principal;

    Contentment::Log->debug('Running Contentment::Security::Manager::end');

    # Save changes to authenticated profiles
    if ($principal->type eq 'authenticated') {
        Contentment::Log->debug(
            'Updating profile of authenticated user %s.', 
            [$principal->username],
        );
        $principal->profile->update;
        $principal->profile->commit;
    }

    # Save their anonymous profile if they had one
    else {
        Contentment::Security::Manager->instance->_save_anonymous_profile(
            $principal,
        );
    }
}

=back

=head2 FORM HANDLER

=over

=item Contentment::Security::Manager::process_login_form

On success, this logs the user in.

It expects the following query parameters:

=over

=item username

This is the username of the user that is logging in.

=item password

This is the password of the user that is logging in.

=back

=cut

sub process_login_form {
    my $self       = Contentment::Security::Manager->instance;
    my $submission = shift;
    my $results    = $submission->results;

    if (!$self->login($results->{username}, $results->{password})) {
        Contentment::Exception->throw(
            message => 'Incorrect username or password.',
        );
    }
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is licensed and distributed under the same terms as perl itself.

=cut

1
