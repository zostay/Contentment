% my $dir = $file->is_container ? $file : $file->parent;
% my @ancestors = $dir->ancestors;
% for my $ancestor (@ancestors) {
<a href="<%$ancestor->path%>"><%
	$ancestor->get_property('short_title') ||
	$ancestor->get_property('title') ||
	($ancestor->is_root ? 'Home' : $ancestor->basename)%></a>
% }
%
% unless (@ancestors) {
&nbsp;
% }

<%args>
$file
</%args>
