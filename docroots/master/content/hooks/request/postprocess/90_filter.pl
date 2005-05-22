use Contentment::VFS;

my $file = $vfs->lookup_source('/content/filter/apply_filter');
$file->generate;
