=begin meta
    description => 'All blog entries.'
    title       => 'Blogs'
=end meta
=cut

$context->security->check_permission('Contentment::Node::Blog::view_blog');

if ($context->security->has_permission(
'Contentment::Node::Blog::edit_blog')) {
    print qq(<p><a href="blog/edit.html">Create Blog</a></p>);
}

my @blogs = Contentment::Node::Blog->search;
$context->theme('blogs', { blogs => \@blogs });
