<%args>
@files
</%args>

% if (@files) {
<ul class="toc">
% my $last_num = scalar(my @x = split '/', $files[0]->path);
% my $num;
% for my $file (@files) {
% 	my $url  = $file->lookup_source->path;
% 	$url =~ s/\.\w+$/\.html/;
%
% 	my $num = scalar(@x = split '/', $file->path);
% 	while ($num > $last_num) {
<ul class="toc">
%		$last_num++;
%	}
%	while ($num <= $last_num) {
</ul>
%		$last_num--;
%	}

	<li class="toc-item">
		<a href="<% $url %>"><% $file->get_property('title') || $file->path %></a> - <% $file->get_property('abstract') %>
	</li>
% }
</ul>
% 	while ($num <= $last_num) {
</ul>
%		$last_num--;
% 	}
% }
