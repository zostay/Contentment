use Test::More tests => 2;
BEGIN { use_ok( Catalyst::Test, 'Contentment' ); }

ok( request('/')->is_success );
