package Contentment::FileType::PL;

use strict;
use warnings;

use base 'Contentment::FileType::POD';

use Carp;
use Log::Log4perl;

my $log = Log::Log4perl->get_logger(__PACKAGE__);

our $VERSION = '0.04';

=head1 NAME

Contentment::FileType::PL - A file type plugin for handling Perl scripts

=head1 DESCRIPTION

This will run an external Perl script within the current interpreter (i.e., no forks).

These Perl scripts can expect a certain set of calling conventions. The Perl script is called within the same interpreter as the rest of Contentment. Basically, the script can be treated as if it were the body of a subroutine (which isn't far from the truth). Arguments are stored in C<@_> and the global variables available in Mason objects are also made available here.

=over

=item $test = Contentment::FileType::PL-E<gt>filetype_match($file)

Returns true if the file name ends with C<.pl>. Returns false otherwise.

=cut

sub filetype_match {
	my $class = shift;
	my $file  = shift;

	return $file->path =~ /\.pl$/;
}

=item $kind = Contentment::FileType::PL-E<gt>real_kind($file)

Returns "C<text/x-perl>".

=cut

sub real_kind {
	my $class = shift;
	my $file  = shift;

	return 'text/x-perl';
}

=item $kind = Contentment::FileType::PL-E<gt>generated_kind($file, @args)

First, this checks to see if the file has a property named "C<kind>" and will use that value above all else for the generated kind.

Failing that, it strips the "C<.pl>" suffix from the file name and uses the inherited C<mimetypes> method to get a reference to L<MIME::Types> and uses that object to determine the file kind from the remainder of the file name.

Failing that, C<undef> is returned.

=cut

sub generated_kind {
	my $class = shift;
	my $file  = shift;

	my $generated_kind;
	unless ($generated_kind = $file->get_property($file, 'kind')) {
		my $path = $file->path;
		$path =~ s/\.pl$//;

		$generated_kind = $class->mimetypes->mimeTypeOf($path);
	}

	return $generated_kind;
}

=item $headers = Contentment::FileType::PL-E<gt>generate_headers($file, @args)

Returns an empty reference to a hash.

=cut

sub generate_headers { return {} }

=item $result = Contentment::FileType::Perl-E<gt>generate($file, @args)

Wraps the contents of the file in an eval as part of a subroutine and calls the subroutine.

=cut

sub generate {
	my $class = shift;
	my $file  = shift;

	my $sub = sub {
		# Prepare the "global" vars
		my %conf      = %{ Contentment->configuration };
		my $base      = $conf{base};
		my $log       = Log::Log4perl->get_logger($file->path);
		my $url       = Contentment->context->m->cgi_object->url;
		my $full_base = Contentment->context->m->cgi_object->url(-base => 1).$base;
		my $vfs       = Contentment::VFS->new;
		my $_____code = $file->content;
		
		# Clear variables out so they aren't closed here.
		my $class = undef;
		my $file  = undef;

		# Do it!
		eval $_____code; 
		croak $@ if $@ 
	};

	$log->is_debug &&
		$log->debug("Running code in '$file'");

#	Carp::cluck("Running code in '$file'");

	return $sub->(@_);
}

=head1 SEE ALSO

L<MIME::Types>, L<Contentment::FileType::POD>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
