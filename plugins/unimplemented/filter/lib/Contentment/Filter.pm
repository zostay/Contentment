<%doc>
Filters are the last processors hacked onto the end of the transformation chain.
Once a document has reached it's final kind, all matching filters are applied to
make any last minute adjustments (such as cleaning up URLs, removing whitespace
that would interfere with XML processing, etc.)

All filters must define a 'kind' attribute which is set to a regular expression
to match against the kind. If the regexp matches, the filter is applied.
</%doc>
<%args>
$final_kind => undef
</%args>
<%perl>
my $output = $m->content;

$final_kind ||= $m->comp("/content/kind/final/kind");
$log->debug("Applying filters for final kind $final_kind");

for my $filename ($vfs->glob("/content/filter/modules/*")) {
	$log->debug("Loading filter component $filename");
	my $comp = $m->fetch_comp("$filename");
	my $kind = $comp->attr('kind');
	if ($final_kind =~ /$kind/) {
		$log->debug("Filter $filename matches $final_kind, applying...");
		my $input = $output;
		$output = undef;
</%perl>
<&| { store => \$output }, $comp, kind => $final_kind &><% $input %></&>
<%perl>
	}
}
</%perl>
<% $output %>