<%init>
use Contentment::Security::DBI;

if (Contentment::Security::DBI->check_login($username, $password)) {
	return $context->action_result('Success');
} else {
	return $context->action_result('Failure');
}
</%init>

<%args>
$username
$password
</%args>
