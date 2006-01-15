package Contentment::Template::Provider;

use strict;
use warnings;

our $VERSION = 0.09;

use Contentment::Log;
use Contentment::Response;
use Contentment::Template::Document;
use IO::NestedCapture 'capture_out';

use base 'Template::Provider';

# TODO We currently assume that any TT2 template is coming from a VFS FileType.
# However, this might need to worry about non-VFS situations someday.
sub fetch {
	my $self = shift;
	my $name = shift;
	my $generator;

	Contentment::Log->debug('Fetching %s for Template Toolkit', [$name]);

	# Is it already a generator?
	if (ref $name && UNIVERSAL::can($name, 'get_property')) {
		$generator = $name;
	}

    # It's a reference to a scalar, just quickly return a document
    elsif (ref $name eq 'SCALAR') {
        my $parser = $self->{PARSER}
            ||= Template::Config->parser($self->{PARAMS})
            ||  return (Template::Config->error(), 
                        Template::Constants::STATUS_ERROR);
        my $parsedoc = $parser->parse($$name, {});
            
		my $data = Template::Document->new($parsedoc);
        $data->blocks->{input} = sub { join '', <STDIN> };

        if (defined $data) {
            return ($data, Template::Constants::STATUS_OK);
        }

        else {
            return ("Could not compile inline template.", 
                    Template::Constants::STATUS_ERROR);
        }
    } 

    # Otherwise, assume a path and try to resolve
    else {
		$generator = Contentment::Response->resolve($name);
	}

	Contentment::Log->debug("Resolved %s template to %s", [$name,$generator]);

	my ($data, $error);
	if ($generator->get_property('for_template_toolkit')) {
		Contentment::Log->debug("Template %s is for Template Toolkit", 
            [$generator]);

		($data, $error) = $self->_compile({ 
            text => scalar($generator->source) 
        }) unless $error;
		$data = $data->{data} unless $error;
	} else {
		Contentment::Log->debug(
            'Template %s is not in Template Toolkit format, creating a custom '
           .'Contentment::Template::Document.', [$generator]);

		$data = Template::Document->new({
            DEFBLOCKS => {
                input => sub { join '', <STDIN> },
            },
			BLOCK => sub { 
				my $context = shift;
				# TODO Create a custom Stash so that we don't have this HACK
				# using undocumented features of Template::Stash.
				my $stash = $context->stash;
				capture_out {
					$generator->generate(%$stash);
				};
				my $out = IO::NestedCapture->get_last_out;
				join '',<$out>;
			},
		});
		$error = Template::Constants::STATUS_OK;
	}
		
	$data->blocks->{input} = sub { join '', <STDIN> } unless $error;
		
	return ($data, $error);
}

1
