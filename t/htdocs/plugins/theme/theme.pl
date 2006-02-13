print "Hello Theme!\n";

my $vfs = $context->vfs;

my $themes = $vfs->lookup('/themes');
print "/themes is a directory\n" 
	if $themes && $themes->is_container;

my $default = $vfs->lookup('/themes/default');
print "/themes/default is a directory\n" 
	if $default && $default->is_container;

my $text = $vfs->lookup('/themes/default/text');
print "/themes/default/text is a directory\n" 
	if $text && $text->is_container;

my $html = $vfs->lookup('/themes/default/text/html');
print "/themes/default/text/html is a directory\n" 
	if $html && $html->is_container;

my $top = $vfs->lookup('/themes/default/text/html/top.tt2');
print "/themes/default/text/html/top.tt2 is a file\n" 
	if $top && $top->has_content;

=begin meta
kind => 'text/html'
=end meta
=cut
