<%args>
$kind
</%args>
<% $m->content %>
<%filter>
s{ (href|src|action)="/}{ $1="$conf{base}/}g;
</%filter>
<%attr>
kind => qr(^text/html$)
</%attr>
