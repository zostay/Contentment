% for my $item (@items) {
<div id="panel-<% $name %>.<% "$item" %>">
% $context->start_panel($url, "$name.$item");
% my ($action, $state, $args) = $m->comp('/content/widget/get_action_result');
% $$args{item} = $item;
<& $map, panel => "$name.$item", action => $action, state => $state, %$args &>
% $context->end_panel;
</div>
% }

<%args>
@items
$name
$map
</%args>
