# vim: set ft=perl:

use strict;

use lib 'buildlib';

use Contentment;
use Contentment::Test;
use Test::More tests => 2;

my $conf = {
          'master_index_default' => 'toc-heir',
          'non_indexed_files' => qr/(?-xism:(?i:index(\.\w+)?$|^\.svn$|^CVS$|^(?:auto|d)handler$|\.sw.$|^\#|~$|\.jpg$|\.gif.bmp$|\.png$|\.o$|^a.out$|\.exe$|^bin$))/,
          'filetype_plugins' => [
                                  'Contentment::FileType::Mason',
                                  'Contentment::FileType::HTML',
                                  'Contentment::FileType::POD',
                                  'Contentment::FileType::PL',
                                  'Contentment::FileType::Other'
                                ],
          'dbi_dsn' => 'dbi:mysql:testdb',
          'site_slogan' => 'Keeping your content happy since 2005.',
          'dbi_pass' => 'testpass',
          'master_default' => 'main',
          'pod_bases' => [
                           '/'
                         ],
          'site_footer' => 'Steep prices and trees!',
          'mason_files' => qr/(?-xism:\.(?:mhtml|mason)$)/,
          'security_module' => 'Contentment::Security::DBI',
          'vfs' => [
                     'Layered',
					 [
					 	'Real',
						'root',
						't/testdocs',
					 ],
                     [
                       'Real',
                       'root',
                       'blib/docroots/sample'
                     ],
                     [
                       'Real',
                       'root',
                       'blib/docroots/master'
                     ]
                   ],
          'base' => '',
          'session_cookie_duration' => '+90d',
          'pod_fallback' => 'http://search.cpan.org/perldoc?',
          'site_logo' => '/content/themes/images/default/logo.png',
          'sql_type' => 'MySQL',
          'site_url' => '/',
          'site_title' => 'Contentment Sample Site',
          'dbi_user' => 'testuser',
          'temp_dir' => '/tmp/Contentment-Test',
          'log4perl_conf' => 't/etc/log4perl.conf',
          'theme_default' => 'default',
          'dbi_opt' => {
                         'LongReadLen' => '65536',
                         'RaiseError' => '1'
                       }
        };

is_deeply(Contentment->configuration, $conf);
is(Contentment->security, $conf->{security_module});
