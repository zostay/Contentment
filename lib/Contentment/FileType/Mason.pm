package Contentment::FileType::Mason;

use strict;
use warnings;

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

sub kind { "mason" }

sub comp {
	my $class = shift;
	my $file  = shift;

	return $file->{ft_comp} if defined $file->{ft_comp};

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

	my $source_file = $file->lookup_source;

	die "Failed to find a proper source for file $file" unless $source_file;

	if (my $comp = $class->comp($source_file)) {
		$log->debug("Compiling/Running component $source_file");
	
		if ($top) {
			my $original_kind;
			unless ($original_kind = $class->property($source_file, 'kind')) {
				if ($file->path =~ /\.m?html$/) {
					$original_kind = 'text/html';
				} elsif ($file->path =~ /\.mason$/) {
					my $path = $file->path;
					s/\.mason$// =~ $path;

					my $mime = MIME::Types->new;
					$original_kind = $mime->mimeTypeOf($path);
				} else {
					$original_kind = 'unknown';
				}
			}

			$log->debug("Mason file generates original kind of $original_kind");
			$Contentment::context->original_kind($original_kind);
			$log->debug("Context is $Contentment::context");
		}

		my $subreq = $Contentment::context->m->make_subrequest(
			comp => $comp, args => [ $Contentment::context->m->request_args ]
		);
		my $result = $subreq->exec;

		my %notes = %{ $subreq->notes };
		while (my ($k, $v) = each %notes) {
			$Contentment::context->m->notes($k => $v);
		}

		return $result;
	} else {
		die "Failed to compile component $source_file: $@";
	}
}

1
