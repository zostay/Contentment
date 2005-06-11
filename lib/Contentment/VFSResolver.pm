package Contentment::VFSResolver;

use strict;
use warnings;

use Contentment::VFS;
use Cwd;
use File::Spec;
use HTML::Mason::ComponentSource;
use Log::Log4perl;
use Params::Validate qw/:all/;

use base qw/ HTML::Mason::Resolver /;

our $VERSION = '0.03';

my $log = Log::Log4perl->get_logger(__PACKAGE__);

=head1 NAME

Contentment::VFSResolver - Subclass of HTML::Mason::Resolver for Contentment::VFS

=head1 DESCRIPTION

Provides Mason with access to the files known to Contentment via
L<Contentment::VFS>.

=cut

# === START HACKS FOR RESOLVER BUGS ===========================================
# Added this stuff to allow this to work---bug in the resolver setup makes me
# need to accept comp_root.

# TODO Remove this when they fix the bug.

__PACKAGE__->valid_params
    (
     comp_root =>
     { parse => 'list',
       type => SCALAR|ARRAYREF,
       default => File::Spec->rel2abs( Cwd::cwd ),
       descr => "A string or array of arrays indicating the search path for component calls" },
    );

sub comp_root {
	my $self = shift;
	die "Resolver comp_root is read-only" if @_;
	return $self->{comp_root}[0][1] if @{$self->{comp_root}} == 1 and $self->{comp_root}[0][0] eq 'MAIN';
	return $self->{comp_root};
}

# === END HACKS FOR RESOLVER BUGS =============================================

sub get_info {
	my $self = shift;
	my $path = shift;

	my $vfs = Contentment::VFS->new;

	$log->debug("VFS Resolver searching for $path");

	if (my $file = $vfs->lookup($path)) {
		$log->debug("VFS Resolver lookup found ", $file->path);

		return HTML::Mason::ComponentSource->new(
			friendly_name   => $file->path,
			comp_id         => $file->path,
			last_modified   => $file->get_property('mtime'),
			comp_path       => $file->path,
			comp_class      => 'HTML::Mason::Component::FileBased',
			source_callback => sub { scalar($file->content) },
			# DUMB! comp_roots shouldn't be needed for anything but the
			# resolver.
			extra           => {
				comp_root => '/tmp/fake-comp-root',
			}
		);
	}

	$log->debug("VFS Resolver lookup found no matching file for $path");
	return;
}

sub glob_path {
	my $self = shift;
	my $glob = shift;

	$log->debug("VFS Resolver globbing for $glob");
	return Contentment::VFS->new->glob($glob);
}

=head1 SEE ALSO 

L<Contentment::VFS>, L<HTML::Mason::Resolver>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<gt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
