package Contentment::FileType::Mason;

use strict;
use warnings;

use base 'Contentment::FileType::Other';

use Log::Log4perl;

our $VERSION = '0.01';

my $log = Log::Log4perl->get_logger(__PACKAGE__);

sub filetype_match {
	my $class = shift;
	my $file  = shift;

	my $conf = Contentment::configuration;

	if ("$file" =~ /$conf->{mason_files}/) {
		return 1;
	} else {
		return '';
	}
}

sub real_kind { "text/x-mason" }

sub generated_kind {
	my $class = shift;
	my $file  = shift;
	
	my $generated_kind;
	unless ($generated_kind = $class->property($file, 'kind')) {
		if ($file->path =~ /\.m?html$/) {
			$generated_kind = 'text/html';
		} elsif ($file->path =~ /\.mason$/) {
			my $path = $file->path;
			s/\.mason$// =~ $path;

			$generated_kind = $class->mimetypes->mimeTypeOf($path);
		}
	}

	return $generated_kind;
}

sub comp {
	my $class = shift;
	my $file  = shift;

	return $file->{ft_comp} if defined $file->{ft_comp};

	$log->debug("Loading component for file $file.");
	$file->{ft_comp} = $Contentment::context->m->fetch_comp($file->path);

	warn "Failed to fetch Mason component for $file"
		unless $file->{ft_comp};

	return $file->{ft_comp};
}

sub property {
	my $class = shift;
	my $file  = shift;
	my $prop  = shift;

	if (my $comp = $class->comp($file)) {
		return $comp->attr_if_exists($prop);
	} else {
		return;
	}
}

sub generate {
	my $class = shift;
	my $file  = shift;
	my $top   = shift;

	if (my $comp = $class->comp($file)) {
		$log->debug("Compiling/Running component $file");

		my $buf;
		my $result = $Contentment::context->m->comp(
			{ store => \$buf }, $comp,
			args => [ $Contentment::context->m->request_args ]
		);

		print $buf;

		return $result;
	} else {
		die "Failed to compile component $file: $@";
	}
}

1
