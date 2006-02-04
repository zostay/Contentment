package Contentment::Build;

use strict;
use warnings;

our $VERSION = '0.011_032';

use base qw( Module::Build );
our @ISA;

use File::Copy;
use File::Path;
use File::Spec;

# Apache::TestMB is entirely too narrow-minded for my purposes. Thus, I've
# stolen the bits I need from it and will just need to update if the internals
# of it's API make significant changes in the future.
#
# The primary purpose of all my fancy build script finagling is to allow for
# lots of automatic testing and to contain the automatic release process. I'm
# the only developer that should be releasing anything, but I wanted to include
# it as part of the build script because it's an obvious place for it and it'll
# make it easier for somebody else in the future to use.
#
# I originally tried Module::Release, but it's really also too narrow-minded.
# Therefore, I learned what I could from it and then did my own thing.
#
# -- Sterling, February 4, 2006

BEGIN {
    eval 'use Apache::Test';
    if (!$@) {
        eval 'sub found_apache_test { 1 }';
    }

    else {
        eval 'sub found_apache_test { 0 }';
    }
}

sub apache_test_script { 't/TEST_APACHE' }

sub ACTION_apache_generate_test_scripts {
    my $self = shift;

    print 'Creating test version of CGI script: ',
          "t/htdocs/cgi-bin/contentment.cgi\n";

    open IN, 'htdocs/cgi-bin/contentment.cgi'
        or die "Cannot open htdocs/cgi-bin/contentment.cgi: $!";
    open OUT, '>t/htdocs/cgi-bin/contentment.cgi'
        or die "Cannot open t/htdocs/cgi-bin/contentment.cgi: $!";

    while (<IN>) {
        if (/^use Contentment;/) {
            print OUT qq{use lib '../../../blib/lib';\n};
#            print OUT qq{use lib '../../lib';\n};
        }
        
        print OUT $_;
    }

    close IN;
    close OUT;

    $self->make_executable('t/htdocs/cgi-bin/contentment.cgi');

    $self->add_to_cleanup('t/htdocs/cgi-bin/contentment.cgi');

    my $content = <<'END_OF_SCRIPT';
#line 72 buildlib/Contentment/Build.pm
use strict;
use warnings;

my $apache_test = Apache::TestRunContentment->new;
$apache_test->run(@ARGV);

package Apache::TestRunContentment;

use base 'Apache::TestRunPerl';

sub pre_configure {
    my $self = shift;

    push @{ $self->{argv} }, glob 't/http/*.t';
}

1

END_OF_SCRIPT

    my $file = $self->localize_file_path($self->apache_test_script);

    my $basic_cfg = Apache::Test::basic_config();
    $basic_cfg->write_perlscript($file, $content);
    $self->add_to_cleanup($self->apache_test_script);
}

sub _bliblib {
    my $self = shift;
    return (
        '-I', File::Spec->catdir($self->base_dir, $self->blib, 'lib'),
        '-I', File::Spec->catdir($self->base_dir, $self->blib, 'arch'),
    );
}

sub ACTION_apache_test_clean {
    my $self = shift;
    $self->depends_on('apache_generate_test_scripts');
    $self->do_system($self->perl, $self->_bliblib,
                     $self->localize_file_path($self->apache_test_script),
                     '-clean');
}

sub ACTION_apache_test {
    my $self = shift;
    $self->depends_on('apache_generate_test_scripts');
    my $success 
        = $self->do_system($self->perl, $self->_bliblib,
                     $self->localize_file_path($self->apache_test_script),
                     '-bugreport', '-verbose='. ($self->verbose || 0 ));

    die "Some tests failed!" unless $success;
}

sub ACTION_standard_test {
    my $self = shift;

    $self->test_files(glob "t/standard/*.t");

    $self->SUPER::ACTION_test(@_);
}

sub ACTION_test {
    my $self = shift;
    
    # Clean-up the database if requested, but only once because of the
    # test_upgrade that might happen later
    if (delete $self->{args}{'cleandb'}) {
        print "Emptying testdb.\n";
        unlink "t/htdocs/cgi-bin/testdb";
    }

    $self->ACTION_standard_test;

    if ($self->found_apache_test) {
        $self->depends_on('code');
        $self->depends_on('apache_test_clean');
        $self->ACTION_apache_test;
    }
}

sub ACTION_list_tests {
    my $self = shift;

    # We have two test sets:
    #  - HTTP     : tests in t/http
    #  - Standard : tests in t/standard

    # HTTP tests
    print "HTTP Tests:\n";
    print "-" x 70,"\n";
    my $tests = $self->test_files(glob "t/http/*.t");
    for my $test (@$tests) {
        print "$test\n";
    }

    # Standard tests
    print "\nStandard Tests:\n";
    print "-" x 70,"\n";
    $tests = $self->test_files(glob "t/standard/*.t");
    for my $test (@$tests) {
        print "$test\n";
    }
}

# This is an insanely helpful automation of the release process to make sure I
# release often (since I failed to release early until this super-duper release
# action as added).

sub ACTION_release {
    my $self = shift;

    # The release action doesn't really do anything itself, except run the
    # rest, but all of these together are insanely useful. INSANELY!

    # Make sure to empty the testdb database.
    $self->{args}{cleandb}++;

    my @tasks = qw(
        test
        test_upgrade
        disttest
        commit
        tag
        status_check
        upload_release_to_PAUSE
        announce_release_on_Freshmeat
    );

    for my $task (@tasks) {
        print "Release Task $task...\n";
        my $success = eval { $self->depends_on($task) };
        if ($@) {
            print STDERR $@ if $@;
            print "release: halted after $task due to failures.\n";
            return;
        }
    }
}

sub do_svn {
    my $self = shift;

    $self->do_system('svn', @_);
}

sub read_svn {
    my $self = shift;

    my $command = "svn ".join(' ', @_);
    print "$command\n";
    open my $fh, "$command|"
        or die "Failed to open pipe to $command for reading: $!";

    return $fh;
}

sub ACTION_test_upgrade {
    my $self = shift;

    my $info = $self->_info();

    if (!$self->_has_anything_changed()) {
        print "Skipping upgrade test because tagging has already happened.\n";
    }

    # Check out the current tag in the tmp directory
    chdir File::Spec->tmpdir;
    $self->do_svn('checkout', "$info->{TAG}/current")
        or die "Failed to checkout $info-{TAG}/current for upgrade testing";
    chdir 'current';

    # Run the tests there to recreate a testdb
    $self->run_perl_script("Build.PL")
        or die "Failed creating Build script.";
    $self->run_perl_script("Build")
        or die "Failed running Build script.";
    $self->run_perl_script("Build", [], ["test"])
        or die "Failed running Build test script.";

    # Return to our directory and copy the testdb
    chdir $self->base_dir;
    copy(
        File::Spec->catfile(
            File::Spec->tmpdir, 'current', 't', 'htdocs', 'cgi-bin', 'testdb'
        ),
        File::Spec->catfile('t', 'htdocs', 'cgi-bin'),
    );

    # Clean-up
    rmtree(File::Spec->catfile(File::Spec->tmpdir, 'current'));

    # Run our tests and see if they pass after upgrading
    $self->ACTION_test;
}

sub ACTION_touch_versions {
    my $self = shift;

    $self->depends_on('touch_lib_versions');
    $self->depends_on('touch_plugin_versions');
}

sub _has_anything_changed {
    my $self = shift;
    my $dir = @_ ? join ' ', @_ : '.';

    my $STATUS = $self->read_svn('status', '-q', $dir);

    my %changes;
    while (<$STATUS>) {
        chomp;
        my ($status, $file) = unpack "A7 A*", $_;
        $changes{ $file } = $status;
    }

    close $STATUS
        or die "Failed to get svn status of $dir: $!";

    return wantarray ? %changes : scalar keys %changes;
}

my $_get_version;
sub _get_version {
    my $self = shift;
    return $_get_version if defined $_get_version;

    # Read the diff for Contentment to see if the VERSION has been updated
    # already and use that if it has
    my $VERDIFF = $self->read_svn('diff', 'lib/Contentment.pm');

    while (<$VERDIFF>) {
        if (($_get_version) = /^\+our \$VERSION = '?([\d\._]+)'?;$/) {
            last;
        }
    }

    close $VERDIFF
        or die "Failed to open svn diff of lib/Contentment.pm: $!";

    # If the diff didn't contain a new version, let's get the old version and
    # increment it
    unless ($_get_version) {
        open VERCONT, "lib/Contentment.pm"
            or die "Failed to open lib/Contentment.pm: $!";

        while (<VERCONT>) {
            if (($_get_version) = /our \$VERSION = '?([\d\._]+)'?;$/) {
                last;
            }
        }

        close VERCONT;

        my $dev = $_get_version =~ s/_//;

        if ($self->_has_anything_changed()) {
            $_get_version += 0.000_001;
        }

        $_get_version = sprintf "%.06f", $_get_version;

        if ($dev) {
            my ($major, $minor_rev) = split /\./, $_get_version;
            my ($minor, $rev) = unpack "A3 A3", $minor_rev;
            $_get_version = "$major.${minor}_$rev";
        }
    }

    unless ($_get_version) {
        die "touch_lib_versions: unable to determine Contentment version";
    }

    return $_get_version;
}

sub _update_version_of_pm {
    my $filename = shift;
    my $version  = shift;

    open INPM, $filename
        or die "Cannot read $filename: $!";

    open OUTPM, ">$filename.tmp"
        or die "Cannot write $filename.tmp: $!";

    while (<INPM>) {
        if (/^our \$VERSION =/) {
            print OUTPM "our \$VERSION = '$version';\n";
        }

        else {
            print OUTPM $_;
        }
    }

    close OUTPM;
    close INPM;
    
    rename $filename, "$filename~" 
        or die "Cannot create backup of $filename as $filename~";
    rename "$filename.tmp", $filename
        or die "Could not move new version of $filename.tmp to $filename";

    print "$filename version $version\n";
}

sub _update_version_of_yml {
    my $filename = shift;
    my $version  = shift;

    # Don't use YAML because we want to preserve formatting

    open INPM, $filename
        or die "Cannot read $filename: $!";

    open OUTPM, ">$filename.tmp"
        or die "Cannot write $filename.tmp: $!";

    while (<INPM>) {
        if (/^version: /) {
            print OUTPM "version: $version\n";
        }

        else {
            print OUTPM $_;
        }
    }

    close OUTPM;
    close INPM;
    
    rename $filename, "$filename~" 
        or die "Cannot create backup of $filename as $filename~";
    rename "$filename.tmp", $filename
        or die "Could not move new version of $filename.tmp to $filename";

    print "$filename version $version\n";
}

sub ACTION_touch_lib_versions {
    my $self = shift;

    # Find the list of modifications
    my %mods = $self->_has_anything_changed('lib', 'buildlib');
    
    # If anything has changed, modify lib/Contentment.pm
    if (keys %mods) {
        $mods{'lib/Contentment.pm'} = 'M';
    }

    # Compute the list of modifications
    my @mods = grep { $mods{$_} =~ /^[AM]/ } keys %mods;

    my $new_version = $self->_get_version();

    print "Contentment version $new_version:\n";

    for my $mod (@mods) {
        _update_version_of_pm($mod, $new_version);
    }
}

sub ACTION_touch_plugin_versions {
    my $self = shift;

    # Find added/modified/deleted files
    my %files = $self->_has_anything_changed('plugins');
    
    my %mods;
    while (my ($filename, $flags) = each %files) {

        # Determine which plugin
        my ($plugin) = $filename =~ m[^plugins/([^/]+)];

        # Skip this file and the plugin altogether if there's no init.yml
        unless (-f "plugins/$plugin/init.yml") {
            print "Not touching $plugin, missing init.yml\n";
            next;
        }

        # Make sure the init.yml file gets updated
        $mods{$plugin}{"plugins/$plugin/init.yml"}++;

        # If the file is added or modified and a pm file, make sure it gets
        # updated as well
        if ($flags =~ /^[AM]/ && $filename =~ /\.pm$/) {
            $mods{$plugin}{$filename}++;
        }
    }

    # Find versions for each plugin
    my %versions;
    for my $plugin (keys %mods) {
        
        # For each modified plugin, read the diff on the init.yml to see if
        # version: has been updated already and use that if it has
        my $new_version;
        my $VERDIFF = $self->read_svn('diff', "plugins/$plugin/init.yml");

        while (<$VERDIFF>) {
            if (($new_version) = /^\+version: ([\d\.]+)/) {
                last;
            }
        }

        close $VERDIFF
            or die "Failed to open diff of plugins/$plugin/init.yml: $!";

        # If the diff didn't contain a new version, let's get the old version
        # and increment it
        unless ($new_version) {
            require YAML;
            my $init = eval { YAML::LoadFile("plugins/$plugin/init.yml"); };

            if ($@) {
                die "Failed to load plugins/$plugin/init.yml: $@";
            }

            $new_version = $init->{version} + 0.01;
        }

        $versions{$plugin} = sprintf '%.02f', $new_version;
    }

    while (my ($plugin, $group) = each %mods) {
        my $version = $versions{$plugin};
        print "$plugin version $version\n";
        for my $file (keys %$group) {
            if ($file =~ /\.pm/) {
                _update_version_of_pm($file, $version);
            }

            elsif ($file =~ /\.yml/) {
                _update_version_of_yml($file, $version);
            }

            else {
                die "Unknown type of file given to version update: $file";
            }
        }
    }
}

sub ACTION_commit {
    my $self = shift;

    # Unfortunately, it appears that svn commit reports normal execution, even
    # if the user aborts, so we'll use the status_check test to confirm success.
    $self->do_svn('commit')
        or die "Failed to commit: $!";

    return 1;
}

sub ACTION_status_check {
    my $self = shift;

    die "Cannot continue because of the above files are not yet committed."
        if $self->_has_anything_changed();
}

# my $info = $self->_info()
#
# This returns useful information about the current repository, to make sure
# that tagging and various actions properly consider branches. This method will
# die if a tag is checked out since we have no business touching tags.
#
# The info is a hash with the following keys:
#
#  * ROOT - This will be the name of the repository root found by taking the
#    "svn info" URL and stripping everything under "trunk" or "branches"
#  * BRANCH - This will be the name of the current trunk or branch URL, which is
#    basically just the "svn info" URL
#  * BRANCH_TITLE - This will be the title of the branch or "trunk" if the
#    current branch is the trunk.
#  * TAG - This will be the name of the URL that should be used as the base for
#    any tags made of the current BRANCH. This is calculated as follows:
#
#      1.  If the BRANCH is the trunk, this will simply be:
#       
#            ROOT/tags/Contentment
#
#      2.  If the BRANCH is a branch, this will be:
#
#            ROOT/tags/Contentment/BRANCH_TITLE
#
sub _info {
    my $self = shift;
    my $INFO = $self->read_svn('info');

    my $info;
    while (<$INFO>) {
        if (($info) = /^URL:\s*(.*)$/) {
            last;
        }
    }

    close $INFO
        or die "Failed to open Subversion info: $!";

    die "Please checkout the trunk or a branch---not a tag."
        if $info =~ /\/tags\//;

    my %results = (
        BRANCH => $info,
    );

    $results{ROOT} = $info;
    $results{ROOT} =~ s/\/(?:trunk|branches).*$//;

    if ($info =~ /\/trunk\//) {
        $results{TAG} = $results{ROOT}.'/tags/Contentment';
        $results{BRANCH_TITLE} = 'trunk';
    }

    elsif (my ($branch_title) = $info =~ /\/branches\/Contentment\/([^\/]+)/) {
        $results{TAG} = $results{ROOT}.'/tags/Contentment/'.$branch_title;
        $results{BRANCH_TITLE} = $branch_title;
    }

    else {
        die "Unknown info URL type: $info";
    }

    return \%results;
}

sub ACTION_tag {
    my $self = shift;

    $self->depends_on('commit');

    # Get the essential information
    my $version = $self->_get_version();
    my $info = $self->_info();

    # List the tags made to make sure we haven't already done this
    my $LIST = $self->read_svn('list', $info->{TAG});

    my %found;
    while (<$LIST>) {
        chomp;
        s/\/$//;
        $found{$_}++;
    }

    close $LIST
        or die "Cannot open Subversion list $info->{TAG}: $!";

    # Did we already do the versioning?
    if ($found{$version}) {
        print "Tags already made. Skip tagging.";
        return 1;
    }

    # else { please continue }

    # Check out the current tag in the tmp directory
    chdir File::Spec->tmpdir;
    $self->do_svn('checkout', "$info->{TAG}/current")
        or die "Failed checkout of $info->{TAG}/current for merging";
    chdir 'current';

    # If these fail we want to make sure we still clean-up
    eval {

        # Merge the current branch into the current tag
        $self->do_svn('merge', "$info->{TAG}/current", $info->{BRANCH})
            or die "Failed merge of $info->{TAG}/current with $info->{BRANCH}";

        # Commit the merge, we assume that the current tag is a tag and hasn't
        # been modified, therefore, no conflicts are possible.
        $self->do_svn('commit', 
            '-m', "Merge $info->{BRANCH_TITLE} $version into current tag.")
                or die "Failed to commit merge of ".
                       "$info->{BRANCH_TITLE} $version";
    };

    my $ERROR = $@;

    # Clean-up
    chdir '..';
    rmtree('current');
    chdir $self->base_dir;

    # Die before we finish the process if we must
    if ($ERROR) {
        die $ERROR;
    }

    # Finally, finish by tagging the branch with it's version number
    $self->do_svn('copy', '-m', "Tagging $info->{BRANCH_TITLE} as $version.",
        $info->{BRANCH}, "$info->{TAG}/$version")
           or die "Failed to tag $info->{BRANCH_TITLE} as $version";

    return 1;
}

# Some hardcoded checks to keep a random person from doing something bad if
# they decide not to use their brain.
sub _STERLING_ONLY {
    my $msg = shift;

    if ($ENV{LOGNAME} ne 'sterling') {
        die "$msg ($ENV{LOGNAME})";
    }

    require Sys::Hostname;
    my $hostname = Sys::Hostname::hostname();
    if ($hostname !~ /^lockhart\b/) {
        die "$msg ($hostname)";
    }

    # If they pass both those on a fluke, oh geez. Forget it. Why the hell are
    # they running ./Build upload_release_to_PAUSE anyway?!
}

sub ACTION_upload_release_to_PAUSE {
    my $self = shift;

    _STERLING_ONLY('Sterling will be ticked off if someone other than him uploads a Contentment release to CPAN. Stop it.');

    my $version = $self->_get_version();

    require YAML;

    # Skip it if we show it's already uploaded
    my $upload = YAML::LoadFile('upload.yml');
    if ($upload->{uploaded}{$version}) {
        print "Contentment-$version.tar.gz was already uploaded. Skipping.\n";
    }
    
    $self->depends_on('tag');
    $self->depends_on('dist');

    require HTTP::Request::Common;
    require LWP::UserAgent;
    require Net::FTP;

    # Upload the file via FTP
    print "Contacting pause.perl.org.\n";
    my $ftp = Net::FTP->new('pause.perl.org')
        or die "Cannot connect to pause.perl.org: $@";
    
    print "Logging in as anonymous : hanenkamp\@cpan.org.\n";
    $ftp->login('anonymous', 'hanenkamp@cpan.org')
        or die "Cannot login as anonymous on pause.perl.org: ",$ftp->message;

    print "Changing into directory /incoming.\n";
    $ftp->cwd('/incoming')
        or die "Cannot cwd into /incoming: ",$ftp->message;

    print "Chaning to binary mode.\n";
    $ftp->binary
        or die "Cannot change mode to binary: ",$ftp->message;
    
    print "Putting file Contentment-$version.tar.gz\n";
    $ftp->put("Contentment-$version.tar.gz")
        or die "Cannot put Contentment-$version.tar.gz into /incoming: ",
               $ftp->message;

    print "Quitting FTP.\n";
    $ftp->quit;

    my $ua = LWP::UserAgent->new
        or die "Cannot initialize LWP::UserAgent: $!";

    my $request = HTTP::Request::Common::POST(
        'http://pause.perl.org/pause/authenquery', {
            HIDDENNAME                    => $upload->{username},
            pause99_add_uri_upload        => "Contentment-$version.tar.gz",
            SUBMIT_pause99_add_uri_upload => " Upload the checked file ",
        },
    );
    $request->authorization_basic(@$upload{qw( username password )});

    print "Notifying PAUSE via HTTP POST of upload.\n";
    my $response = $ua->request($request);

    if (!defined $response) {
        die "Failed to get a response from PAUSE: $!";
    }

    elsif ($response->is_error) {
        die "PAUSE returned an error page: ",
            $response->code," ",$response->message;
    }

    else {
        # Let me know
        print "Uploaded Contentment-$version.tar.gz to PAUSE.\n";

        # Make sure we note the upload so we don't try again
        $upload->{uploaded}{$version}++;
        YAML::DumpFile('upload.yml', $upload);
        
        # Notify the caller that we're happy
        return 1;
    }
}

sub ACTION_announce_release_on_Freshmeat {
    my $self = shift;

    print STDERR "announce: Not yet implemented\n";
}

sub ACTION_manifest {
    my $self = shift;

    my %files;

    my $LIST = $self->read_svn('list', '-R');

    while (<$LIST>) {
        chomp;
        $files{ $_ } ++ if -f;
    }

    close $LIST
        or die "Failed to open Subversion file list: $!";

    my %mods = $self->_has_anything_changed;
    while (my ($filename, $mod) = each %mods) {
        if ($mod =~ /^A/ && -f $filename) {
            $files{ $filename } ++;
        }
    }

    open MANIFEST, ">MANIFEST"
        or die "Failed to open MANIFEST for overwriting: $!";

    for my $name (sort keys %files) {
        print MANIFEST $name,"\n";
        print "Added to MANIFEST: ",$name,"\n";
    }

    close MANIFEST;
}

1
