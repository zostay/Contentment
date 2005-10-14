<%args>
$dir              => '.'
$offset           => 0
$limit            => 0
$order_by         => 'path'
$kind             => undef
$theme            => 'default'
$master           => 'toc-hier'
$recursive        => 1
$include_dirs     => 0
$exclude_root     => 0
@excludes         => ()
@exclude_children => ()
$prune_unindexed  => 1
</%args>

<%init>
if ($dir !~ /^\//) {
	$dir = $m->caller->dir_path."/$dir";
	$log->debug("Indexing directory '$dir'");
}
</%init>

<%perl>
use Scalar::Util qw/looks_like_number/;

sub smart_cmp {
	my $arg = shift;
	my $sort_mult = 1;

	if ($arg =~ /^-/) {
		$arg = substr $arg, 1;
		$sort_mult = -1;
	}

	my $first  = $a->get_property($arg);
	my $second = $b->get_property($arg);

	if (looks_like_number($first) && looks_like_number($second)) {
		($first <=> $second) * $sort_mult;
	} else {
		($first cmp $second) * $sort_mult;
	}
}

my @files = $vfs->find(sub {
	my $file = local $_ = shift;

	return 0 if $file eq $vfs->lookup($dir);

	if (/$conf{non_indexed_files}/) {
		$file->is_container and $File::System::prune = 1;
		return 0;
	}

	for my $exclude (@exclude_children) {
		if (/$exclude/) {
			$file->is_container and $File::System::prune = 1;
		}
	}

	for my $exclude (@excludes) {
		if (/$exclude/) {
			$file->is_container and $File::System::prune = 1;
			return 0;
		}
	}

	if ($file->is_container) {
		$File::System::prune = 1 unless $recursive;
		
		$File::System::prune = 1 if $prune_unindexed && !$file->lookup_source;

		return 0 unless $file->lookup_source;
	
		return 0 unless $include_dirs;
	}


	return 1;
}, $dir);

@files = sort { smart_cmp($order_by) } @files;

if ($offset || $limit) {
	my $start = $offset || 0;
	my $end   = $limit ? $start + $limit : $#files;
	$end = $end > $#files ? $#files : $end;
}

$log->debug("Index returning these files: ",join(' ', @files));

my $final_kind = $kind || $m->comp('/content/kind/final/kind');
</%perl>

<& "/content/themes/$theme/$final_kind/$master", files => \@files &>