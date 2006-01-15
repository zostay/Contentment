package TestNode;

use strict;
use warnings;

use base 'Contentment::Node::Revision';

our $VERSION = '0.01';

our $schema = {
    attributes => [
        {
            name => 'title',
            type => 'String',
        },
        {
            name => 'content',
            type => 'Text',
        },
    ],
};

__PACKAGE__->auto_deploy(1);

1
