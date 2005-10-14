<%init>
if ($file->get_property('cache') && $top) {
	$log->debug("Caching enabled for $url");

	my $content = $m->cache->get($url, 
		busy_lock => $file->get_property('cache_busy_lock'),
		expire_if => sub {
			my $obj = shift;
			my $change_clears = $file->get_property('cache_change_clears');
			return defined $change_clears && $change_clears != 0
				&& $obj->get_create_at < $file->get_property('mtime');
		},
	);
	
	unless (defined $content) {
		my %opts = ();
		$opts{expires_in} = $file->get_property('cache_expires_in')
			if $file->get_property('cache_expires_in');
		$m->cache->set($url, $content = $m->content, %opts);

		$log->debug("Setting the cache for $url");
	} else {
		$log->debug("Loaded content from cache for $url");
	}

	$m->print($content);
} else {
	$log->debug("Caching disabled for $url");
	$m->print($m->content);
}

return;
</%init>
<%args>
$file
$top => 0
</%args>
