package Contentment::Template::Provider;

use strict;
use warnings;

our $VERSION = '0.01';

use Contentment::Log;
use Contentment::Response;
use Contentment::Template::Document;

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
	} else {
		$generator = Contentment::Response->resolve($name);
	}

	Contentment::Log->debug("Resolved %s template to %s", [$name,$generator]);

	my ($data, $error);
	if ($generator->get_property('for_template_toolkit')) {
		Contentment::Log->debug("Template %s is for Template Toolkit", [$generator]);

		($data, $error) = $self->_compile({ text => scalar($name->content) })
			unless $error;
		$data = $data->{data} unless $error;
	} else {
		Contentment::Log->debug("Template %s is not in Template Toolkit format, creating a custom Contentment::Template::Document.", [$generator]);

		$data = Template::Document->new({
			BLOCK     => sub { shift->{GENERATOR}->generate(@_) },
			GENERATOR => $generator,
		});
		$error = Template::Constants::STATUS_OK;
	}
		
	$data->blocks->{input} = sub { print <STDIN> } unless $error;
		
	return ($data, $error);
}

1
