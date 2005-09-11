<div id="panel-<% $name %>">
% $context->start_panel($url, $name, $map);
% my ($action, $state, $args) = $m->comp('/content/widget/get_action_result');
<& $map, panel => $name, action => $action, state => $state, %$args &>
% $context->end_panel;
</div>

<%args>
$name
$map
</%args>
