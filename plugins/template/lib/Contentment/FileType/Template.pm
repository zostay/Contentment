package Contentment::FileType::Template;

use strict;
use warnings;

our $VERSION = '0.04';

use base 'Contentment::FileType::Other';

use Contentment::Hooks;
use Contentment::Log;
use Contentment::Template;

sub real_kind {
	return 'text/x-template-toolkit-2';
}

sub generated_kind {
	my $class = shift;
	my $file  = shift;

	# Strip off the .tt2 extension
	my $file_without_ext = $file->basename;
	$file_without_ext =~ s/\.tt2$//;

	# Return the MIME-Type of the nested extension or return the contents of the
	# "kind" metadata field.
	return eval { 
        $class->mimetypes->mimeTypeOf($file_without_ext) 
		    || Contentment::Template->new_template->context
                ->template($file)->kind 
    };
}

sub properties { ('for_template_toolkit') }

sub get_property {
	my $class = shift;
	my $file  = shift;
	my $key   = shift;

	die "Bad key '$key'." unless $key =~ /^\w+$/;

	return 1 if $key eq 'for_template_toolkit';

	return Contentment::Template->new_template->context->template($file)->$key;
}

sub generate_headers { () }

sub generate {
	my $class = shift;
	my $file  = shift;
	my %args  = @_;

    my $tt = Contentment::Template->new_template;

    $tt->process($file, { args => \%args })
		or die $tt->error();

	return 1;
}

sub match {
	local $_ = ''.shift;
	/\.tt2/ && return 'Contentment::FileType::Template';
	return undef;
}

1
