print q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>};
print Contentment::Response->properties->{title} || Contentment::Response->properties->{path};
print q{</title>
<link rel="STYLESHEET" type="text/css" href="/themes/default/style/main.css"/>
};
if (Contentment::Response->properties->{description}) {
	my $desc = Contentment::Response->properties->{description};
	print qq{<meta name="description" content="$desc"/>\n};
}
print q{</head>
<body>
<div id="content">
};
print <STDIN>;
print q{</div>
</body>
</html>};
