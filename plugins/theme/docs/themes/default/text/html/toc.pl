<div class="toc">
% for my $file (@files) {
% 	my $html = "$file";
% 	$html =~ s/\.\w+$/\.html/;
	<div class="toc-item">
		<a href="<% $html %>"><% $file->get_property('title') || $file->path %></a> - <% $file->get_property('abstract') %>
	</div>
% }
</div>

<%args>
@files
</%args>

