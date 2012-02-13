#! @PERL@
# Copyright (c) 2008, 2009, 2010 Zmanda, Inc.  All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
#
# Contact information: Zmanda Inc., 465 S. Mathilda Ave., Suite 300
# Sunnyvale, CA 94086, USA, or: http://www.zmanda.com

use strict;
use warnings;
use Pod::Html;
use File::Basename;
use File::Path;
use File::Temp;

my ($targetdir, @sources) = @ARGV;
@sources = sort @sources;

my $version = "@VERSION@";
my $version_comment = @VERSION_COMMENT@;
my $version_major = "@VERSION_MAJOR@";
my $version_minor = "@VERSION_MINOR@";
my $version_patch = "@VERSION_PATCH@";
my $pod_path;
if ($version_comment eq "") {
    $pod_path = "/pod/$version_major.$version_minor.$version_patch";
} elsif ($version_comment =~ /beta\d*/) {
    $pod_path = "/pod/$version_major.$version_minor.$version_patch$version_comment";
} elsif ($version_comment =~ /alpha/ or $version_comment =~ /beta/) {
    $pod_path = "/pod/beta";
} else {
    $pod_path = "/pod/$version_major.$version_minor";
}

my %dirs = ( '' => 1 );
my ($dir, $pm);

sub pm2html {
	my ($pm) = @_;
	$pm =~ s{\.pm$}{.html};
	return $pm;
}

sub pm2module {
	my ($pm) = @_;
	$pm =~ s{/}{::}g;
	$pm =~ s{\.pm$}{};
	return $pm;
}

sub pm2css {
	my ($pm) = @_;
	$pm =~ s{[^/]*/}{../}g;
	$pm =~ s{/[^/]*$}{/};
	$pm .= "amperl.css";
	return $pm;
}

# generate the HTML
for $pm (@sources) {
    my $module = pm2module($pm);
    my $html = pm2html($pm);
    my $fh;
    my $generated = gmtime();

    print "Converting $pm to $html\n";

    $dir = dirname($pm);
    $dirs{$dir} = 1;

    mkpath("$targetdir/$dir");

    # slurp the source
    open ($fh, "<", $pm) or die("Error opening $pm: $!");
    my $pod = do { local $/; <$fh> };
    close ($fh);

    # set up a temporary input file for a modified version of the POD
    my $tmp = File::Temp->new();
    open ($fh, ">", $tmp->filename) or die("Error opening $tmp: $!");

    # now prepend and append a header and footer
    print $fh <<HEADER;

=begin html

HEADER

    my $module_parent = $module;
    my $index;
    my $dir1 = $pm;
    $dir1 =~ s/\.pm$//;
    if (-d $dir1) {
	$dir1 =~ s{^.*/}{}g;
	print $fh "<a href=\"$dir1/index.html\">$module_parent Module list</a><br />\n";
    }

    $module_parent =~ s{::[^:]*$}{};
    $index = "index.html";
    my $moduleX;
    my $count = 1;
    do {
	print $fh "<a href=\"$index\">$module_parent Module list</a><br />\n";
	$moduleX = $module_parent;
	$module_parent =~ s{::[^:]*$}{};
	$index = "../" . $index;
	$count++;
	die() if $count > 5;
    } while $moduleX ne $module_parent;

    print $fh <<HEADER;
<div class="pod">
<h1 class="module">$module</h1>

=end html

=cut
HEADER
    print $fh $pod;
    print $fh <<FOOTER;

=head1 ABOUT THIS PAGE

This page was automatically generated $generated from the Amanda source tree,
and documents the most recent development version of Amanda.  For documentation
specific to the version of Amanda on your system, use the 'perldoc' command.

=begin html

</div>

=end html

=cut
FOOTER
    close ($fh);

    my $css = pm2css($pm);
    pod2html("--podpath=Amanda",
	    "--htmldir=$targetdir",
	    "--infile=$tmp",
	    "--css=$css",
	    "--noindex",
	    "--outfile=$targetdir/$html");

    # post-process that HTML
    postprocess("$targetdir/$html", $module);
}

sub postprocess {
    my ($filename, $module) = @_;

    # slurp it up
    open(my $fh, "<", $filename) or die("open $filename: $!");
    my $html = do { local $/; <$fh> };
    close($fh);

    $html =~ s{<title>.*</title>}{<title>$module</title>};
    $html =~ s{<body>}{<body></div><center>$version<hr></center>};
    $html =~ s{<link rev="made" [^>]*/>}{};
    $html =~ s{html">the (\S+) manpage</a>}{html">$1</a>}g;
    $html =~ s{</body>}{</div><hr><center>$version</center></body>};
    # write it out
    open($fh, ">", $filename) or die("open $filename: $!");
    print $fh $html;
    close($fh);
}

# and generate an index HTML for each new directory
# we created.
for $dir (keys %dirs) {
	my $css;
	if ($dir) {
		$css = pm2css("$dir/");
	} else {
		$css = "amperl.css";
	}
	my $module = $dir;
	$module =~ s{/}{::}g;
	open(my $idx, ">", "$targetdir/$dir/index.html") or die("Error opening $dir/index.html: $!");
	print $idx <<HEADER;
<?xml version="1.0" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<link rel="stylesheet" href="$css" type="text/css"
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
</head>
<body></div><center>$version<hr></center>
HEADER
	my $module_parent = $module;
print STDERR "module: $module\n";
	$module_parent =~ s{::[^:]*$}{};
	my $index = "../index.html";
	my $moduleX;
	my $count = 1;
	do {
		print $idx "<a href=\"$index\">$module_parent Module list</a><br />\n";
		$moduleX = $module_parent;
		$module_parent =~ s{::[^:]*$}{};
		$index = "../" . $index;
		$count++;
		die() if $count > 5;
	} while $moduleX ne $module_parent;

	print $idx <<BODY;
<div class="pod">
<h1 class="module">$module Module List</h1>
<ul>
BODY
	for $pm (@sources) {
		my $html = pm2html($pm);
		my $mod = pm2module($pm);
		next unless ($pm =~ /^$dir/);
		if ($dir) {
			if ($pm =~ /^$dir\//) {
				$html =~ s{^$dir/}{}g;
			} else {
				$html =~ s{^[^/]*/}{../};
			}
		}
		print $idx " <li><a href=\"$html\">$mod</a>\n";
	}
	print $idx <<'FOOTER';
</ul>
</div>
</body>
</html>
FOOTER
}
