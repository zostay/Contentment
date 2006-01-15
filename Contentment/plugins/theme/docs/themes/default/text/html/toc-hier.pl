my $self = shift;
my %args = @_;
my @files = @{ $args{files} || [] };

if (@files) {
	print q(<ul class="toc">);
	my $last_num = scalar(my @x = split m[/], $files[0]->path);
	my $num;
	for my $file (@files) {
		my $src = $file->lookup_source;
        my $gen = $src->generator;
		my $url = $src->path;
		$url =~ s/\.\w+$/\.html/;

		my $num = scalar(@x = split m[/], $file->path);
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
			<a href="$url">).($gen->get_property('title') || $gen->path).q(</a> - ).$gen->get_property('abstract').q(
				</li>
			);
	}

	while ($num < $last_num) {
		print q(</ul>);
		$last_num--;
	}
}
