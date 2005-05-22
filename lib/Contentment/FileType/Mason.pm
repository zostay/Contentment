package Contentment::FileType::Mason;

use strict;
use warnings;

use base 'Contentment::FileType::Other';

use Log::Log4perl;

our $VERSION = '0.03';

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::FileType::Mason - This file type plugin is used to represent HTML::Mason files

=head1 DESCRIPTION

This file type is able to extract properties from L<HTML::Mason> formatted files and to generate the output from those files.

=over

=item $test = Contentment::FileType::Mason-E<gt>filetype_match($file)

Given a file C<$file> returns whether or not it should be considered a Mason file. This determination is made on the bases of the C<mason_files> configuration variable.

=cut

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

=item $kind = Contentment::FileType::Mason-E<gt>real_kind($file)

Returns "C<text/x-mason>".

=cut

sub real_kind { "text/x-mason" }

=item $kind = Contentment::FileType::Mason-E<gt>generated_kind($file)

This test is currently hardwired. Though, it seems a bit odd to have C<filetype_match> configurable, but C<generated_kind> hardwired.

First, this checks to see if the file has a property named "C<kind>" and will use that value above all else for the generated kind.

Failing that, it checks to see if the file name ends with either "C<.mhtml>" or "C<.html>". If it does, it returns "C<text/html>".

Failing that, it checks to see if the file name ends with "C<.mason>". If it does, it uses the inherited C<mimetypes> method to get a reference to L<MIME::Types> and uses that object to determine the filetype from the file name with the "C<.mason>" stripped off.

Failing that, we return C<undef>.

=cut

sub generated_kind {
	my $class = shift;
	my $file  = shift;
	
	my $generated_kind;
	unless ($generated_kind = $file->get_property($file, 'kind')) {
		if ($file->path =~ /\.m?html$/) {
			$generated_kind = 'text/html';
		} elsif ($file->path =~ /\.mason$/) {
			my $path = $file->path;
			$path =~ s/\.mason$//;

			$generated_kind = $class->mimetypes->mimeTypeOf($path);
		}
	}

	return $generated_kind;
}

=item $comp = Contentment::FileType::Mason-E<gt>comp($file)

Returns the Mason component object for the given file.

=cut

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

=item @properties = Contentment::FileType::Mason-E<gt>properties($file)

Returns the names of all the properties found in the file.

=cut

sub properties {
	my $class = shift;
	my $file  = shift;

	if (my $comp = $class->comp($file)) {
		return $comp->attributes;
	} else {
		return ();
	}
}

=item $value = Contentment::FileType::Mason-E<gt>get_property($file, $key)

Checks to see if the Mason component for C<$file> contains an attribute named C<$key> and returns that attribute.

=cut

sub get_property {
	my $class = shift;
	my $file  = shift;
	my $prop  = shift;

	if (my $comp = $class->comp($file)) {
		return $comp->attr_if_exists($prop);
	} else {
		return;
	}
}

=item $result = Contentment::FileType::Mason-E<gt>generate($file, @args)

Runs the Mason component for C<$file>. The output is captured and printed out to the currently C<select>ed file handle. The result of running the component is returned.

=cut

# FIXME Generate uses an "unsupported" feature of Mason to set the content. This
# should probably be fixed up to use an anonymous Mason component handler or
# something. Perhaps that will be a good thing to do once we aren't using Mason
# as the front-loader anymore.

sub generate {
	my $class = shift;
	my $file  = shift;
	my %args  = @_;

	if (my $comp = $class->comp($file)) {
		$log->debug("Compiling/Running component $file");

		my %content;
		if ($args{content}) {
			my $content = delete $args{content};
			$content{content} = $content;
		}

		my $buf = '';
		my $result = $Contentment::context->m->comp(
			{ 	content => sub { 
					my $m = $Contentment::context->m;
					while (<STDIN>) {
						$m->print($_);
					}
				},
				store => \$buf,
			}, 
			$comp,
			$Contentment::context->m->request_args,
			%args,
		);

		print $buf;

		return $result;
	} else {
		die "Failed to compile component $file: $@";
	}
}

=back

=head1 SEE ALSO

L<HTML::Mason>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
