package Contentment::Form;

use strict;
use warnings;

our $VERSION = '0.10';

use Contentment::Exception;
use Contentment::Form::Definition;
use Contentment::Form::Submission;
use File::Spec;
use List::Util qw( reduce );
use Params::Validate qw( validate_with :types );
use Test::Deep::NoTest;

=head1 NAME

Contentment::Form - forms API for Contentment

=head1 SYNOPSIS

  # Typically, you want a two part Perl-script. The first part sets up the form
  # definition and initial data. The second is a template for rendering.

  my $template = <<'END_OF_TEMPLATE';
  [% form.begin %]

  [% form.widgets.username.label.render %] [% Form.widgets.username.render %]
  <br/>

  [% form.widgets.password.label.render %] [% Form.widgets.password.render %]
  <br/>

  [% form.widgets.submit.render %]
  [% form.end %]
  END_OF_TEMPLATE

  my $form = $context->form->define({
      name     => 'Contentment::Security::Manager::login_form',
      method   => 'POST',
      action   => 'Contentment::Security::Manager::process_login_form',
      activate => 1,
      template => [ Template => {
          source     => $template,
          properties => {
              kind => 'text/html',
          },
      ],
      widgets  => [
          username => {
              name  => 'username',
              class => 'Text',
          },
          password => {
              name  => 'password',
              class => 'Text',
              type  => 'password',
          },
          submit => {
              value => 'Login',
              class => 'Submit',
          },
      ],
  });

  if ($form->submission->is_finished) {
      $context->response->redirect('index.html')->generate;
  }

  else {
      print $form->render;
  }

=head1 DESCRIPTION

One of the biggest hassles of writing a web application is handling the forms. It's such a domain-specific hassle that there aren't many general solutions out there and the ones I looked at couldn't handle the needs of Contentment. So, I wrote my own---though, if I can eventually extrapolate this into a more general offering, I hope to do so.

Using this forms system in Contentment involves the following steps:

=over

=item 1.

B<Definition.> First you must define the form. This is done using the C<define()> method. This specifies widgets used and the general structure of the data to be entered into the form.

=item 2.

B<Rendering.> Once defined, the form is rendered. The definition should include a template that can be used to render the form fields. Rendering occurs via the C<render()> method of the object returned by the C<define()> method.

=item 3.

B<Client-side Validation.> As of this writing, client-side validation is pretty sparse. However, as the API matures, this will be fleshed out more. Client-side validation performs a sanity check on the data prior to submission to help save the user some time.

It's important to note that client-side validation is of secondary importance. Server-side validation is the most important because we can't ultimately trust client-side validation. Some clients may not support it. Malicious clients will purposely ignore it. Thus, we must provide server-side validation. Client-side validation is just icing on the cake.

=item 4.

B<Server-side validation.> Once the client hits the submit button, we need to make sure the data given is sane. Validation performs the task of making sure each piece of data is well-formed and performs any data conversion necessary to make the data useful to our code.

It is very important that this process is done very carefully. If this step isn't taken seriously our code will contain security vulnerabilities.

Server-side validation is performed by the "Contentment::Form::process" hook handler, which then calls the C<validate()> method for each widget associated with the form.

=item 5.

B<Activation.> If the submitted form has the activation flag set, we need to take action. Action will only be taken if the activation flag is set and the form has passed validation with no errors. Once activated, the subroutine associated with the form will be executed with the validated data.

Activation is performed by the "Contentment::Form::process", which calls the action subroutine associated with the form.

=item 6.

B<Finished.> If the action executes without error, the form submission is marked as finished.

The form is finished within the "Contentment::Form::process" hook handler when the action subroutine executes without throwing an exception.

=back

=head2 METHODS

The C<Contentment::Form> class defines the following methods:

=over

=cut

sub new {
    my $class = shift;
    return bless {}, $class;
}

=item $form = $context-E<gt>form-E<gt>define(\%args)

This method is used to construct a form's definition. The form definition is stored the the L<Contentment::Form::Definition> class.

This method returns an instance of L<Contentment::Form::Definition>, which has methods for rendering and such.

A form definition accepts the following arguments:

=over

=item name (required)

This is the name of the form. This name should be unique throughout your application. It is recommended that you use a Perl package or subroutine name for this string to make sure it is unique.

For example, consider these names:

  Contentment::Security::Manager::login_form
  Contentment::Security::Profile::Persistent::edit_user_form
  Contentment::Setting::edit_setting_form

=item action (optional)

This is the name of the subroutine responsible for taking action when the form is submitted. If not given, the action defaults to "Contentment::Form::process_noop". This form handler is pretty much what it says, a no-op. It does nothing, but allows you to perform actions late in the process if you need lightweight form handling.

The action subroutine should expect a single argument, the data constructed by the validation step. The subroutine will not be called unless the form has passed validation without any errors.

  sub form_action {
      my $results = shift;

      Contentment->context->security_manager->login(
          $results->{username},
          $results->{password},
      );
  }

The action subroutine should throw an exception on failure so that the form can be kept unfinished and be reactivated by the user. On success, the subroutine should exit normally (the return value is ignored).

=item widgets (required)

This option must be set to a reference to an array containing the definition of each widget to be used in the form. Each widget is defined as a key/value pair as if it were a reference to a hash (i.e., the order the widgets are defined is significant). The keys are mnemonic names that are used to look the widget up via the C<widgets()> method of L<Contentment::Form::Definition>. The values are passed to the widgets' constructors. 

Each value is a hash of options. One of the options should be named "class" and should either be the full name of the widget class or the last element of the class name if it is defined under the "Contentment::Form::Widget::" namespace.

For example:

  widgets => [
      username => {
          name  => 'username',
          class => 'Text',
      },
      password => {
          name  => 'password',
          class => 'Text',
          type  => 'password',
      },
  ],

=item template (optional)

This is the generator factory method arguments used to construct a generator object responsible for rendering the template. This comes in the form of an array reference where the first argument is the name of the generator class and the second argument is the hash containing the arguments for the generator constructor. The arguments must be serializable with L<YAML>.

The C<generate()> method of the object will be passed the C<%vars> hash, which is the second argument to the C<render()> method of the form definition object.

When you need to access the form definition within the template, use the C<form()> method of L<Contentment::Form> to retrieve the currently rendering form.

Under most circumstances, you should avoid specifying the template directly. Instead, the template can be specified as part of the theme. This way, your forms will render according to the theme designer's wishes.

However, the default rendering options will surely not suit every circumstance, so providing your own template may be required. The simplest template possible looks something like this (using a Template Toolkit template):

  [% USE Form %]
  [% Form.begin %]

  [% FOREACH widget IN Form.widgets %]
  [% Form.render_widget(widget) %]
  [% END %]

  [% Form.end %]

or (using a Perl template):

  my $form = Contentment::Form->form;
  print $form->start();

  for my $widget (@{ $form->widgets }) {
      print $form->render_widget($widget);
  }

  print $form->end();

Make sure to at least include the C<start()> and C<end()> form calls before and after rendering any widgets, respectively. Use the C<render_widget()> method whenever you don't need to customize the rendering of your widgets so that the template designer has as much say as possible.

Make sure you read the descriptions for C<start()>, C<end()>, and C<render_widget()> before writing your own template. You will also need to konw how to use the C<begin()>, C<end()>, and C<render()> methods of each of the widgets you are using.

=item activate (optional, defaults to false)

If submission of this form should result in the form being activated, set this argument to a true value. 

This is not part of the persistent form definition.

=item enctype (optional, defaults to "application/x-www-form-urlencoded")

This is the encoding the form will be submitted in. Make sure to set this to "multipart/form-data" if you include any file upload widgets.

=item method (optional, defaults to "POST")

This determines how the form will be submitted. This defaults to "POST", so make sure to change this to "GET" if you need/want the query parameters to show up in the user's location bar (i.e., if you want a form submission to be bookmarkable).

This system is really overkill for most kinds of "bookmarkable" forms like a search engine or something similar might want. In the future, this might be better, but it's really kind of ugly right now.

=back

=cut

sub _load_widget_class {
    my $self = shift;

    # Only load sane widget classes
    if ($_[0] =~ /^[\w:]+/) {
        if ($_[0] !~ /::/) {
            $_[0] = "Contentment::Form::Widget::$_[0]";
        }

        eval "use $_[0]";
        Contentment::Log->warning(
            'An exception occurred while loading widget class %s: %s',
            [$_[0], $@]
        ) if $@;
    }

    # Complain, the widget class was un-sane
    else {
        Contentment::Exception->throw(
            message => 'A failure occurred while trying to load a form widget.',
            details => qq(Widget class "$_[0]" is not sane.),
        );
    }
}

my @differing_reasons = (
    'Not different',
    'Actions are different',
    'Encoding types are different',
    'Methods are different',
    'Templates are different',
    'Widget parameters are different',
);

sub define {
    my $self = shift;
    my %p = validate_with(
        params => \@_,
        spec   => {
            name => {
                type  => SCALAR,
                regex => qr/^[\w:]+$/,
            },
            action => {
                type    => SCALAR | UNDEF,
                regex   => qr/^[\w:]+$/,
                default => 'Contentment::Form::process_noop',
            },
            template => {
                type    => ARRAYREF,
                default => '',
            },
            widgets => {
                type => ARRAYREF,
            },
            activate => {
                type    => BOOLEAN,
                default => 0,
            },
            enctype  => {
                type    => SCALAR | UNDEF,
                default => 'application/x-www-form-urlencoded',
            },
            method   => {
                type    => SCALAR | UNDEF,
                default => 'POST',
            },
        },
    );

    # First, check to see if the this_submission is given for the same name. If
    # so we can skip most of the hard work and just use that definition!
    my $definition;
    my $this_submission = $self->this_submission;
    if (defined $this_submission
    && $this_submission->definition->form_name eq $p{name}) {
        Contentment::Log->debug(
            'Found a last submission for %s definition.',
            [$p{name}]
        );
        $definition = $this_submission->definition;
    }

    # Otherwise, we need to do the hard work to load the definition...
    else {
        Contentment::Log->debug(
            'No last submission. Will have to create/find a definition.'
        );
        
        # Find any previous definitions
        my @definitions = Contentment::Form::Definition->search({
            form_name => $p{name},
        });

        # Try to recover an old definition
        if (@definitions) {
            # Find the latest definition
            my $latest_definition 
                = reduce { $a->version > $b->version ? $a : $b }
                         @definitions;

            Contentment::Log->debug(
                'Found a definition for form "%s" at version %d.',
                [$p{name}, $latest_definition->version]
            );

            # Check for sameness
            my $different =
                  $latest_definition->action   ne $p{action}   ? 1
                : $latest_definition->enctype  ne $p{enctype}  ? 2
                : $latest_definition->method   ne $p{method}   ? 3
                : !eq_deeply(
                    $latest_definition->template,
                    $p{template})                              ? 4
                : !eq_deeply(
                    $latest_definition->widget_parameters, 
                    $p{widgets})                               ? 5
                :                                                0
                ;

            # Create a new one if it's different
            if ($different) {
                Contentment::Log->debug(
                    'This form differs from stored. Creating a new definition '
                   .'for form %s (%d): %s.', 
                    [$p{name},$different,$differing_reasons[$different]]
               );

                $definition = Contentment::Form::Definition->create({
                    form_name         => $p{name},
                    version           => $latest_definition->version + 1,
                    action            => $p{action},
                    enctype           => $p{enctype},
                    method            => $p{method},
                    template          => $p{template},
                    widget_parameters => $p{widgets},
                });
            } 
            
            # Reuse the same old one
            else {
                Contentment::Log->debug(
                    'This form matches the stored form %s.', [$p{name}]
                );
                $definition = $latest_definition;
            }
        }

        # Otherwise, create a new definition
        else {
            Contentment::Log->debug(
                'No previous form definition stored. Creating first '
               .'deifnition for form %s.', [$p{name}]
            );

            $definition = Contentment::Form::Definition->create({
                form_name         => $p{name},
                version           => 1,
                action            => $p{action},
                enctype           => $p{enctype},
                method            => $p{method},
                template          => $p{template},
                widget_parameters => $p{widgets},
            });
        }

        Contentment::Log->debug(
            'Creating a new submission for form %s.', [$p{name}]
        );

        # Create a new submission
        my $submission = Contentment::Form::Submission->create;
        $submission->definition($definition);
        $submission->update;

        $definition->submission($submission);

        # Since ::Definition only holds a weak reference, we store an extra
        # reference just to keep ::Submission from disappearing early
        push @{ $self->{submissions_from_define} }, $submission;

        # We don't need the above trick when loading a submission for
        # processing later, because this_submission will point to it for the
        # duration of the request.
    }

    # Update the database
    $definition->update;
    $definition->commit;

    # Setup the non-persistent attributes
    $definition->activate($p{activate});

    Contentment::Log->debug(
        'Constructing widgets for form %s.', [$p{name}]
    );

    # Construct the widgets
    my (@widgets, %widgets);
    my @widget_parameters = @{ $definition->widget_parameters };
    while (my ($key, $value) 
    = splice @{ $definition->widget_parameters }, 0, 2) {
        my %widget_parameters =  %$value;
        my $widget_class = delete $widget_parameters{class};
        $self->_load_widget_class($widget_class);

        eval {
            push @widgets, $widgets{$key} 
                = $widget_class->construct(\%widget_parameters);
        };

        if ($@) {
            Contentment::Exception->throw(
                message => qq(Error constructing widget "$key": $@),
            );
        }
    }
    $definition->widgets(\@widgets);
    $definition->widgets_by_name(\%widgets);

    # Done, return it.
    return $definition;
}

=item $submission = $context-E<gt>form-E<gt>this_submission

This method returns C<undef> unless this request processed a submission. In that case, it returns the submission object processed.

=cut

sub this_submission {
    my $self = shift;

    return defined $self->{this_submission}
            ? $self->{this_submission}
            : undef;
}

=item $definition = $context-E<gt>form-E<gt>this_definition

This method returns the form that is currently being rendered or C<undef> if no form is being rendered.

=cut

sub form {
    my $self = shift;
    return $self->{definition};
}

=head2 CONTEXT

This package adds the following context methods:

=over

=item $form = $context->form

Returns an instance of the L<Contentment::Form> class used to process and define forms for the current request.

=cut

sub Contentment::Context::form {
    my $ctx = shift;
    return defined $ctx->{form} ? $ctx->{form} :
        Contentment::Exception->throw(message => "Form is not available.");
}

=back

=head2 HOOK HANDLERS

=over

=item Contentment::Form::install

Handles teh Contentment::install hook. Deploys the submission and definition classes.

=cut

sub install {
    my $context = shift;
    my $storage = $context->storage;
    $storage->deployClass('Contentment::Form::Definition');
    $storage->deployClass('Contentment::Form::Submission');
}

=item Contentment::Form::begin

This handler is for the "Contentment::begin" hook. It adds the F<docs> folder to the VFS.

=cut

sub begin {
    my $context = shift;

    Contentment::Log->debug("Calling hook handler Contentment::Form::begin");
    my $vfs = $context->vfs;
    my $settings = $context->settings;
    my $plugin_data = $settings->{'Contentment::Plugin::Form'};
    my $docs = File::Spec->catdir($plugin_data->{plugin_dir}, 'docs');
    $vfs->add_layer(-1, [ 'Real', 'root' => $docs ]);

    $context->{form} = Contentment::Form->new;
}

=item Contentment::Form::process

This handler is for the "Contentment::Request::begin" hook. It checks to see if any form is incoming. If so, it attempts to validate and, if activated, process the form using the given action.

=cut

sub process {
    my $self = Contentment::Form->new;
    my $ctx  = shift;
    my $cgi  = $ctx->cgi;

    $ctx->{form} = $self;

    # With every form they must give us the FORM argument.
    if (my $form_name = $cgi->param('FORM')) {
        Contentment::Log->debug('Processing the form named %s', [$form_name]);

        my $submission;
        my $definition;

        # Attempt to load the submission from the form
        my $submission_id;
        if ($submission_id = $cgi->param('ID')) {
            ($submission) = Contentment::Form::Submission->search({
                submission_id => $submission_id,
            });

            $definition = $submission->definition;

            if (!defined $definition) {
                Contentment::Exception->throw(
                    message => "The submission $submission_id has no "
                              ."definition!",
                );
            }

            # Make sure the submission is for the right form!
            if ($definition->form_name ne $form_name) {
                my $bad_form_name = $submission->form->form_name;
                Contentment::Exception->throw(
                    message => 
                        'Attempt to make a submission with mismatched '
                       .'form data.',
                    details => 
                        qq(Recieved a form submission ID $submission_id, which )
                       .qq(is for form "$bad_form_name", but the form )
                       .qq(submitted says its name is "$form_name".),
                );
            }       
        }

        # No submission, we need to create one from scratch
        else {
            # Find the definition
            my @definitions = Contentment::Form::Definition->search({
                form_name => $form_name,
            });
            $definition = reduce { $a->version > $b->version ? $a : $b }
                                 @definitions;

            # Create the submission and link it to this definition
            $submission = Contentment::Form::Submission->create;
            $submission->definition($definition);
        }

        # Set the definition's weak submission reference
        $definition->submission($submission);

        # Remember the current ID for debugging
        $submission_id = $submission->submission_id;

        # Usernames/sessions cannot change between submissions. This generally
        # indicates an expired session.
        #
        # XXX When this happens we need store the submission, redirect the user
        # to a login prompt, when the user successfully logs in we should come
        # back and finish the submission as if we never left.
        my $principal = Contentment->context->security->get_principal;
        if ($submission->username ne $principal->username) {
            Contentment::Exception->throw(
                message => 
                    'You are logged in as a different user than originally '
                   .'viewed this form. You need to login again as '
                   .$submission->username.'.',
                details =>
                    "Submission $submission_id user "
                   .$submission->username
                   ."does not match current user "
                   .$principal->username,
            );
        }

        if ($submission->session_id ne $ctx->session_id) {
            Contentment::Exception->throw(
                message =>
                    'Your session has expired. You need to login again.',
                details =>
                    "Submission $submission_id belongs to an expired session.",
            );
        }

        my %widgets;
        my %results;
        my %cgi_vars = $cgi->Vars;
        for (values %cgi_vars) { $_ = /\0/ ? [ split /\0/ ] : $_ }

        $submission->errors({});

        # Now, iterate through the widgets and lets load the data.
        my @widgets = @{ $definition->widget_parameters };
        while (my ($key, $params) = splice @widgets, 0, 2) {
            my %p = %$params; # modify a copy!

            # Build the widget and validate
            my $widget_class = delete $p{class};
            $self->_load_widget_class($widget_class);
            my $widget = $widget_class->construct(\%p);
            $widgets{$key} = $widget;

            # Report on errors
            my $widget_results = eval { 
                $widget->validate($submission, \%cgi_vars) 
            };
            if ($@) {
                Contentment::Log->debug(
                    'Validation failed on widget "%s": %s', [$key, $@]
                );

                if (UNIVERSAL::isa($@, 'Contentment::ValidationException')) {
                    $submission->errors->{$key} = $@->message;
                    $widget_results = $@->results;
                }
                else {
                    $submission->errors->{$key} = $@;
                    $widget_results = {};
                }
            }

            # Collect the results
            %results = ( %results, %$widget_results );
        }

        $submission->results(\%results);
        $definition->widgets(\%widgets);

        my $activated = $cgi->param('ACTIVATE');
        
        if ($activated && !keys %{ $submission->errors }) {
            Contentment::Log->debug('Form ID %s has been activated and there '
                .'were no validation errors.', [$submission_id]);

            # First note that activation really happened and setup the
            # results
            $submission->is_activated(1);
            $submission->results(\%results);

            # Run the action
            {
                no strict 'refs';
                eval {
                    $submission->definition->action->($submission);
                };

                # On error, report and undo activation
                if ($@) {
                    Contentment::Log->debug(
                        'Form ID %s failed it: %s', [$submission_id,$@]
                    );
                    $submission->is_activated(0);

                    if (UNIVERSAL::isa($@, 'Contentment::Exception')) {
                        $submission->errors->{FORM}
                            = $@->message;
                    }

                    else {
                        $submission->errors->{FORM} = $@;
                    }
                }

                # On success, note the finishing of the form submission
                else {
                    Contentment::Log->debug(
                        'Form ID %s is finished.', [$submission_id]
                    );
                    $submission->is_finished(1);
                }
            }

        }

        Contentment::Log->debug('Setting current_submission to submission '
            .'with submission ID %s', [$submission_id]);

        $self->{this_submission} = $submission;

        $submission->update;
        $submission->commit;
    }
}

=back

=head2 FORM PROCESSORS

=over

=item Contentment::Form::process_noop

This form handler does nothing. It is the default action if none are specified to the C<define()> method and is useful if you need extremely lightweight form handling.

=cut

sub process_noop { }

=back

=head2 FORM GUTS

Basically, forms work pretty much like any form. The documentation for each widget should make it clear how the various attributes of the HTML tags are set. 

However, there are a few special hidden form tags added to every form generated by L<Contentment::Form>. This section describes those tags and their purpose.

=over

=item FORM

This is a requirement for every C<Contentment::Form>. Any CGI submission not including this parameter will be ignored by the C<Contentment::Form> processor. Thus, if you want to create forms that are not processed by this processor, make certain there is no variable named "FORM".

The value of the variable is the form name. If no "ID" variable is included with the submission, the processor attempts to load a form definition for the given form name. If one is found, then a submission will be created and filled using the data found there. This allows for mechanize scripts to run without having to load the initial form page first and form results to be more easily bookmarked.

=item ID

This is an optional field for submissions, but is provided any time a form is rendered. This field specifies the submission ID for the form submission, which allows for the processor to keep a running tally of forms. Eventually, this will be the mechanism by which multi-page forms are made possible.

=item ACTIVATE

This is an optional field that should be set to "1" if the processor should attempt to run the associated action for the submission. Activation will proceed only if the form is found to be completely valid.

=back

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
