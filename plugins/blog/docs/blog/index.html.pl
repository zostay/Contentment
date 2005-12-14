=begin meta
    description => 'All blog entries.'
    title       => 'Blogs'
=end meta
=cut

Contentment::Security->check_permission('Contentment::Node::Blog::view_blog');

if (Contentment::Security->has_permission(
'Contentment::Node::Blog::edit_blog')) {
    print qq(<p><a href="blog/edit.html">Create Blog</a></p>);
}

my @blogs = Contentment::Node::Blog->search;
Contentment::Theme->theme('blogs', { blogs => \@blogs });
