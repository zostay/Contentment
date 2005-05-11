use Contentment::VFS;

my $vfs = $vfs->lookup('/content/transform/apply_transformation');

my $fh = IO::String->new;
my $old_fh = select $fh;

$file->generate(content => $Contentment::context{output});

select $old_fh;

$Contentment::context{output} = ${ $fh->string_ref };
