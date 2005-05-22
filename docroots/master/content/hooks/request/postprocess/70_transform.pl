use Contentment::VFS;

my $file = $vfs->lookup_source('/content/transform/apply_transformation');
$file->generate;
