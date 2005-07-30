package Contentment::Transform::Pod2Html;

use strict;
use warnings;

our $VERSION = '0.01';

use Contentment;

use base qw/ Pod::Simple /;

my $conf = Contentment::configuration;
my $vfs  = Contentment::VFS->new;

=head1 NAME

Contentment::Transform::Pod2Html - Uses Pod::Simple to create an HTML fragment

=head1 DESCRIPTION

This is used by the L</content/transform/modules/pod2html> module to create HTML fragements from POD documents in a way that is appropriate for Contentment.

=cut

sub _handle_element_start {
	my $self = shift;
	local $_ = shift;
	my $attr = shift;

	my $ofh = select $self->{output_fh};

	SWITCH: {
		/^Document$/ && do {
			print qq(<div class="document">\n);
			last SWITCH;
		};
		/^Para$/ && do {
			print qq(<p>);
			last SWITCH;
		};
		/^B$/ && do {
			print qq(<strong>);
			last SWITCH;
		};
		/^I$/ && do {
			print qq(<em>);
			last SWITCH;
		};
		/^C$/ && do {
			print qq(<code>);
			last SWITCH;
		};
		/^F$/ && do {
			print qq(<span class="filename">);
			last SWITCH;
		};
		/^S$/ && do {
			print qq(<span style="white-space: pre-wrap">);
			last SWITCH;
		};
		/^X$/ && do {
			$self->{'contentment_pod2html_skip_x'}++;
			last SWITCH;
		};
		/^L$/ && do {
			$self->{'contentment_pod2html_link_type'} = $attr->{type};

			if ($attr->{type} eq 'url') {
				print qq(<a href="$attr->{to}">);
			} elsif ($attr->{type} eq 'man') {
				$self->{'contentment_pod2html_link_man'} = $attr->{to};
				$self->{'contentment_pod2html_link_man_section'} = $attr->{section};
			} elsif ($attr->{type} eq 'pod') {
				my $link;
				my $target;

				if (defined $attr->{to}) {
					my $file = $attr->{to};
					$file =~ s/::/\//g;

					for my $pod_base (@{ $conf->{pod_bases} }) {
						if ($vfs->lookup_source("$pod_base/$file.html")) {
							$link = "$pod_base/$file.html";
							last;
						}
					}

					unless (defined $link) {
						$target = "_blank";
						$link   = "$conf->{pod_fallback}$attr->{to}";
					}
				}
				if (defined $attr->{section}) {
					$link .= "#$attr->{section}";
				}

				print qq(<a ).
					(defined $target?qq(target="$target" ):'').
					qq(href="$link">);
			} else {
				warn "Unknown link type $attr->{to} given; time to update ",__PACKAGE__;
			}
			last SWITCH;
		};
		/^Verbatim$/ && do {
			print qq(<pre>);
			last SWITCH;
		};
		/^head([1-4])$/ && do {
			print qq(<h$1>);
			last SWITCH;
		};
		/^over-bullet$/ && do {
			print qq(<ul>\n);
			last SWITCH;
		};
		/^item-(bullet|number)$/ && do {
			print qq(<li>);
			last SWITCH;
		};
		/^over-number$/ && do {
			print qq(<ol>\n);
			last SWITCH;
		};
		/^over-text$/ && do {
			$self->{'contentment_pod2html_over_text_first'}++;
			print qq(<dl>\n);
			last SWITCH;
		};
		/^item-text$/ && do {
			my $first = delete $self->{'contentment_pod2html_over_text_first'};
			print qq(</dd>\n) unless defined $first;
			print qq(<dt>);
			last SWITCH;
		};
		/^over-block$/ && do {
			print qq(<blockquote>);
			last SWITCH;
		};
		DEFAULT: {
			warn "Unknown Pod::Simple parser event '$_'; time to update ",__PACKAGE__;
			last SWITCH;
		}
	}
	
	select $ofh;
}

sub _handle_element_end {
	my $self = shift;
	local $_ = shift;
	
	my $ofh = select $self->{output_fh};

	SWITCH: {
		/^Document$/ && do {
			print qq(</div>\n);
			last SWITCH;
		};
		/^Para$/ && do {
			print qq(</p>\n);
			last SWITCH;
		};
		/^B$/ && do {
			print qq(</strong>);
			last SWITCH;
		};
		/^I$/ && do {
			print qq(</em>);
			last SWITCH;
		};
		/^C$/ && do {
			print qq(</code>);
			last SWITCH;
		};
		/^[BS]$/ && do {
			print qq(</span>);
			last SWITCH;
		};
		/^X$/ && do {
			delete $self->{'contentment_pod2html_skip_x'};
			last SWITCH;
		};
		/^L$/ && do {
			my $type = delete $self->{'contentment_pod2html_link_type'};

			if ($type =~ /^(?:url|pod)$/) {
				print qq(</a>);
			} elsif ($type eq 'man') {
				my $to = delete $self->{'contentment_pod2html_link_man'};
				my $section = delete $self->{'contentment_pod2html_link_man_section'};

				if (defined $section) {
					print qq{ (see <span class="manpage-section">"$section"</span> in <span class="manpage">$to</span>)};
				} else {
					print qq{ (see <span class="manpage">$to</span>)};
				}
			}
			last SWITCH;
		};
		/^Verbatim$/ && do {
			print qq(</pre>\n);
			last SWITCH;
		};
		/^head([1-4])$/ && do {
			print qq(</h$1>\n);
			last SWITCH;
		};
		/^over-bullet$/ && do {
			print qq(</ul>\n);
			last SWITCH;
		};
		/^item-(?:bullet|number)$/ && do {
			print qq(</li>\n);
			last SWITCH;
		};
		/^over-number$/ && do {
			print qq(</ol>\n);
			last SWITCH;
		};
		/^over-text$/ && do {
			my $first = delete $self->{'contentment_pod2html_over_text_first'};
			print qq(</dd>\n) unless defined $first;
			print qq(</dl>\n);
			last SWITCH;
		};
		/^item-text$/ && do {
			print qq(</dt>\n<dd>);
			last SWITCH;
		};
		/^over-block$/ && do {
			print qq(</blockquote>);
			last SWITCH;
		};
	}
	
	select $ofh;
}

sub _handle_text {
	my $self = shift;
	local $_ = shift;

	return if $self->{'contentment_pod2html_skip_x'};

	s/&/&amp;/g;
	s/</&lt;/g;
	s/>/&gt;/g;

	print {$self->{output_fh}} $_;
}

=head1 SEE ALSO

L<Pod::Simple>

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@users.sourceforge.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 Andrew Sterling Hanenkamp. All Rights Reserved.

Contentment is distributed and licensed under the same terms as Perl itself.

=cut

1
