<%args>
$src_uri => $url
$panel
$action
$state
</%args>

<%init>
if ($context->has_panel) {
	if (!defined $action) {
		return $m->comp('/content/redirect', to => '/content/security/dbi/log.html');
	} elsif ($action eq '/content/security/dbi/check_login') {
		if ($state eq 'Success') {
			return $m->comp('/content/redirect', to => '/content/security/dbi/log.html');
		} elsif ($state eq 'Failure') {
			return $m->comp('/content/redirect', to => '/content/security/dbi/log.html', failure => 1);
		} else {
			return $m->comp('/content/redirect', to => '/content/security/dbi/log.html');
		}
	} else {
		return $m->comp('/content/redirect', to => '/content/security/dbi/log.html');
	}
} else {
	return $m->comp('/content/redirect', to => '/content/security/dbi/log.html');
}
</%init>
