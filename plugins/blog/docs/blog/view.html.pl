=begin meta
    description => 'A blog entry.'
    title       => 'Blog'
=end meta
=cut

$context->security->check_permission('Contentment::Node::Blog::view_blog');

my $self = shift;
my %args = @_;

my $blog = Contentment::Node::Blog->retrieve($args{id});
$self->properties->{title}       = $blog->title;
$self->properties->{description} = $blog->description;
$context->theme('blog', { blog => $blog });
