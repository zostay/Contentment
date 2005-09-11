package Module::Release::HANENKAMP;

use strict;

use base 'Module::Release::NIKC';

sub make_cvs_tag {
	my $self = shift;
	my ($major, $minor, $dev) = $self->{remote} =~ /(\d+)\.(\d+)(?:_(\d+))?(?:\.tar\.gz)?$/;
	return "$major.$minor".($dev ? ".$dev-Beta" : "");
}

sub get_changes {
	open my $fh, 'svn log svn+ssh://sterling@contentment.org/home/sterling/svn/trunk/Contentment|' or return '';

	my $version;
	my @changes;

	while (<$fh>) {
		if ($version && /-{40}/) {
			last;
		} elsif (/^Contentment /) {
			$version = $_;
		} elsif (/^\s+\*\s+.+$/) {
			push @changes, $_;
		} elsif (/^\s+.+$/) {
			$changes[-1] .= $_;
		}
	}

	my $data = "$version\n";
	$data .= join('', @changes);

	return $data;
}

1
