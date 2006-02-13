package Contentment::Node::Blog;

use strict;
use warnings;

our $VERSION = '0.08';

use base 'Contentment::Node::Revision';

use Class::Date qw( now );
use IO::NestedCapture qw( capture_out );

=head1 NAME

Contentment::Blog - A blog module

=head1 DESCRIPTION

This is a module for creating blogs.

=cut

our $schema = {
    attributes => [ {
        name => 'title',
        type => 'String',
    }, {
        name => 'description',
        type => 'String',
    }, {
        name => 'pub_date',
        type => 'DateTime',
    }, {
        name => 'author',
        type => 'String',
    }, {
        name => 'generator_class',
        type => 'String',
    }, {
        name => 'content',
        type => 'Text',
    }, ],
};

sub generator {
    my $self = shift;
    return Contentment::Generator->generator($self->generator_class, {
        source     => $self->content,
        properties => {
            title       => $self->title,
            description => $self->description,
            pub_date    => $self->pub_date,
            author      => $self->author,
        },
    });
}

sub install {
    my $context = shift;
    __PACKAGE__->storage->deployClass(__PACKAGE__);

    $context->security->register_permissions(
        'Contentment::Node::Blog::view_blog' => {
            title       => 'view blog',
            description => 'User is allowed to view blog entries.',
        },
        'Contentment::Node::Blog::edit_blog' => {
            title       => 'edit blog',
            description => 'User is allowed to create/edit blog entries.',
        },
    );
}

sub begin {
    my $context = shift;
    my $vfs = $context->vfs;
    my $settings = $context->settings;
    my $plugin_data = $settings->{'Contentment::Plugin::Blog'};
    my $docs = File::Spec->catdir($plugin_data->{plugin_dir}, 'docs');
    $vfs->add_layer(-1, [ 'Real', root => $docs ]);
}

sub mimetypes {
    my $types = shift;

    my $rss = MIME::Type->new(
        extensions => [ qw( rss rdf ) ],
        type       => 'application/rss+xml',
    );

    $types->addType($rss);
}

sub process_edit_form {
    Contentment->context->security->check_permission(
        'Contentment::Node::Blog::edit_blog');

    my $submission = shift;
    my $results    = $submission->results;

    # They've asked for an update
    if ($results->{submit} eq 'Update') {

        # Are we creating or editting?
        if ($results->{id}) {
            my $blog = Contentment::Node::Blog->retrieve($results->{id});

            $blog->title($results->{title});
            $blog->description($results->{description});
            $blog->content($results->{content});

            $blog->update;
            $blog->commit;
        }

        else {
            Contentment::Node::Blog->create({
                title       => $results->{title},
                description => $results->{description},
                pub_date    => now,
                author      => Contentment->context->security->get_principal->username,
                generator_class => 'HTML',
                content     => $results->{content},
            });
        }
    }

    # else { do nothing }
}

sub blog_menu {
    my $self = shift;
    capture_out {
        Contentment::Hooks->call('Contentment::Node::Blog::blog_menu');
    };
    my $fh = IO::NestedCapture->get_last_out;
    return join '', <$fh>;
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
