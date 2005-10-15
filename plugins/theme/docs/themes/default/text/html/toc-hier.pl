my %args = @_;
my @files = @{ $args{files} || [] };

if (@files) {
	print q(<ul class="toc">);
	my $last_num = scalar(my @x = split m[/], $files[0]->path);
	my $num;
	for my $file (@files) {
		my $src = $file->lookup_source;
		my $url = $src->path;
		$url =~ s/\.\w+$/\.html/;

		my $num = scalar(@x = split m[/], $file->path);
#		print "<pre>path = ".$file->path.", last_num = $last_num, num = $num</pre>";
		while ($num > $last_num) {
			print q(<ul class="toc">);
			$last_num++;
		}
		while ($num < $last_num) {
			print q(</ul>);
			$last_num--;
		}
		print qq(
			<li class="toc-item">
			<a href="$url">).($src->get_property('title') || $src->path).q(</a> - ).$src->get_property('abstract').q(
				</li>
			);
	}

	while ($num < $last_num) {
		print q(</ul>);
		$last_num--;
	}
}
