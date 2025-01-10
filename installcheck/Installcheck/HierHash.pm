use strict;
use Storable qw(dclone);

{
    package HierHash;
    {
	package HHKey;
	my $key = "keys";

	sub new {
	    my $class = shift;
	    my $self = {};
	    # TODO: Handle another HHKey as initializer.
	    # TODO: Verify the arguments are suitable as keys.
	    @{$self->{$key}} = @_;
	    $self->{depth} = scalar(@{$self->{$key}});
	    return bless $self, $class;
	}

	sub keys {
	    my $self = shift;
	    return $self->{$key};
	}

	sub to_string {
	    my $self = shift;
	    return join(" -> ", @{$self->keys()});
	}
    }

    sub new {
	my $class = shift;
	my $self = {};
	# TODO: Handle another HierHash as initializer.
	$self->{"href"} = shift;
	*{HierHash::each} = \&HierHash::_each_init;
	return bless $self, $class;
    }

    sub lookup {
	my ($self, $hkey) = @_;

	my $href = $self->{"href"};
	foreach my $k (@{$hkey->keys()}) {
	    $href = $href->{"dir"} if (ref($href) eq "HASH" &&
				       defined($href->{"dir"}));
	    if (ref($href) && defined($href->{$k})) {
		$href = $href->{$k};
	    } else {
		return undef;
	    }
	}
	return $href;
    }

    sub keys {
	my ($self) = @_;
	*{HierHash::each} = \&HierHash::_each_init;
	if (!$self->{"cache"}{"keys"}) {
	    my @keys = ();
	    my $hhkey = FTKey->new();

	    # Initialize top level key and spec.
	    # We'll add elements to this array as we discover sub-hashes.
	    my @specs = ( { key => $hhkey, spec => $self->{"href"} } );

	    for (my $i = 0; $i <= $#specs; $i += 1) {
		my $hhkey = $specs[$i]{"key"};
		my %spec = %{$specs[$i]{"spec"}};
		my @tkeys = @{$hhkey->keys()};
		while (my ($key, $val) = each( %spec )) {
		    my $ckey = FTKey->new((@tkeys, @{[$key]}));
		    my $dir;
		    $dir = $val->{"dir"} if (ref($val));
		    push(@keys, $ckey);
		    # If the value is a sub-hash, add it and its key to the spec list.
		    if (ref($dir) eq "HASH") {
			# We need to do deep clone of specs in order to avoid
			#  sharing structures and confusing 'each'.
			my $nspec = { key => $ckey, spec => Storable::dclone($dir) };
			push(@specs, $nspec);
		    }
		}
	    }
	    @{$self->{"cache"}{"keys"}} = @keys;
	}
	return $self->{"cache"}{"keys"};
    }

    sub values {
	my ($self) = @_;
	my @values = ();
	*{HierHash::each} = \&HierHash::_each_init;

	my @keys = $self->keys();
	for my $key (@keys) {
	    my $val = $self->lookup($key);
	    push(@values, $val);
	}
	return @values;
    }

    sub _each_init {
	my ($self) = @_;
	my $key_index = 0;
	my @keys = $self->keys();
	my ($key, $val);

	# Redefine the method
	*{HierHash::each} = sub {
	    my ($self) = @_;

	    if ($key_index <= $#keys) {
		$key = $keys[$key_index];
		$val = $self->lookup($key);
		$key_index += 1;
		return ($key, $val);
	    } else {
		*{HierHash::each} = \&HierHash::_each_init;
		@keys = ();
		return ();
	    };
	};
	$self->each();
    }

    1;
}

use File::Copy;
use File::Find;
use File::Path;
use File::Spec::Functions qw( catdir catpath splitpath splitdir );

{
    package SFPath;

    sub new {
	my $class = shift;
	my $self = {};
	# TODO: Handle another SFPath as initializer.
	$self->{"dirs"} = shift;
	$self->{"file"} = shift;
	$self->{depth} = scalar(@{$self->{"dirs"}});
	return bless $self, $class;
    }

    sub to_string
    {
	my $self = shift;
	my $sfpath = shift;

	my $str = join("/", @{$self->{"dirs"}}, $self->{"file"});
	return $str;
    }

    package FileTree;

    use parent -norequire, 'HierHash';

=head1 NAME

FileTree -- A hierarchical hash representing actions to be taken on elements 
of a filesystem tree.

=head1 SYNOPSIS

=head1 INTERFACE

The hash keys are regular expressions which may be matched against file or
directory names in the hierarchy. Each key represents a regular expression
matching a file or directory name:
=over
=item an RE ending in '/' is a directory entry
=item an RE ending in '[^/][^?]' is a file entry
=item an RE ending in '/?' can match either a file or directory
=item an RE begining with '/*' will match any entry below this level of the
hierarchy
    use FileTree;
=cut
    {
        package FTKey;
        use parent -norequire, 'HHKey';

        sub new {
	    my $class = shift;
	    my $self = {};

	    $self = $class->SUPER::new(@_);
	    $self->{val} = undef;
	    return $self;
	}
    }

    sub new {
	my $class = shift;
	my $self = {};
	my $srcdir = shift;
	my $dstdir = shift;
	my $ospec = shift;

	sub add_spec {
	    my $self = shift;
	    my $ospec = shift;
	    my %spec;

	    # Build a mew spec hash with explicit fields to track matches.
	    while (my ($key, $val) = each( %$ospec )) {
		my %nspec = ( count => 0, dir => undef, complexity => 0, treat => 0 );
		# If the value is a ref (to a hash), the key is a directory.
		if (my $ref = ref($val)) {
		    if ($ref eq "HASH") {
			$nspec{"dir"} = add_spec($self, $val);
			$nspec{"treat"} = 1;
		    } elsif ($ref eq "CODE") {
			$nspec{"treat"} = $val;
		    } else {
			die "FileTree::new - unexpected ref: $ref";
		    }
		} else {
		    $nspec{"treat"} = $val;
		}
		if (FileTree::is_wild_down($self, $key)) {
		    $nspec{"complexity"} += 10;
		}
		# Keys can indicate they match files, directories, or both,
		#  so we need to check for both.
		if (FileTree::is_dir($self, $key)) {
		    $nspec{"complexity"} += 2;
		}
		if (FileTree::is_dir($self, $key)) {
		    $nspec{"complexity"} += 1;
		}
		$spec{$key} = \%nspec;
	    }
	    return \%spec;
	}

	my $spec = add_spec($self, $ospec);
	$self = $class->SUPER::new($spec);
	$self->{"cache"} = { keys => undef, key_depth => undef };
	$self->{"srcdir"} = $srcdir;
	$self->{"dstdir"} = $dstdir;
	$self->{"debug"} = 0;
	return $self;
    }

    sub is_dir {
	my $self = shift;
	my $key = shift;

	my $base_pattern = substr($key, index($key,":") + 1, -1);
	my $dir_pos = length($base_pattern) - 2;
	if (rindex($base_pattern, '/') >= $dir_pos) {
	    return 1;
	} else {
	    return 0;
	}
    }

    sub is_file {
	my $self = shift;
	my $key = shift;

	my $base_pattern = substr($key, index($key,":") + 1, -1);
	my $dir_pos = length($base_pattern) - 2;
	if (rindex($base_pattern, '/') <= $dir_pos) {
	    return 1;
	} else {
	    return 0;
	}
    }

    sub is_wild_down {
	my $self = shift;
	my $key = shift;

	my $base_pattern = substr($key, index($key,":") + 1, -1);
	if (index($base_pattern, '/*') == 0) {
	    return 1;
	} else {
	    return 0;
	}
    }

    sub _gen_key_depths {
	my $self = shift;

	$self->{"cache"}{"key_depth"} = ();
	$self->{"cache"}{"key_depth"}[0] = [];
	foreach my $key (@{$self->keys()}) {
	    my @keys = @{$key->keys()};
	    my $depth = scalar(@keys);
	    # If any sub-key is wild, put this in the wild-card (depth 0) slot
	    foreach my $skey (@keys) {
		if ($self->is_wild_down($skey)) {
		    $depth = 0;
		    last;
		}
	    }
	    push(@{$self->{"cache"}{"key_depth"}[$depth]}, $key);
	}
	@{$self->{"cache"}{"key_depth"}[0]} = sort { $a->{depth} <=> $b->{depth} } @{$self->{"cache"}{"key_depth"}[0]};
    }

    sub find_matches {
	my $self = shift;
	my $sfpath = shift;
	my $href = $self->{"href"};
	my @results = ();

	# Ensure each directory name has a trailing '/' since our
	#  directory keys expect that.
	my @match_path = map { $_ . "/" } @{$sfpath->{"dirs"}};
	my $file = $sfpath->{"file"};
	push(@match_path, $file) if ($file);
	my $depth = scalar(@match_path);

	if (!$self->{"cache"}{"key_depth"}) {
	    $self->_gen_key_depths();
	}

	my $test_keys = $self->{"cache"}{"key_depth"};
	my @match_keys = ();

	# Candidate keys for matches are wildcards (depth 0) with a depth
	#  less than the current path depth, and keys in the current path depth slot
	my @keys = ();
	foreach my $wkey (@{$test_keys->[0]}) {
	    last if scalar(@{$wkey->{"keys"}}) > $depth;
	    push(@keys, $wkey);
	}
	push(@keys, @{$test_keys->[$depth]}) if ($depth <= $#{$test_keys});

      CHECK_KEY:
	foreach my $key (@keys) {
	    my $test_match_keys = $key->keys();
	    my $test_match_key_depth = scalar(@{$test_match_keys});
	    for (my $i = 0; $i < $depth && $i < $test_match_key_depth; $i += 1) {
		my $path = $match_path[$i];
		my $mkey = $$test_match_keys[$i];
		if (!($path =~ m/$mkey/)) {
		    next CHECK_KEY;
		}
	    }
	    push(@match_keys, $key);
	    my $val = $self->lookup($key);
	    $val->{"count"} += 1;
        }
	return @match_keys;
    }
    
    # Return the treat (0 or 1) and the key responsible for it.
    sub do_treat {
	my $self = shift;
	my $sfpath = shift;
	my @match_keys = @_;
	my $t_key;
	my $t_val;
	my $treat;
	my $module = "do_treat";

	sub modified_between {
	    my $self = shift;
	    my $sfpath = shift;
	    my $after = shift;
	    my $before = shift;
	    my $result = 0;

	    my $filename = $self->{"srcdir"} . $sfpath->to_string();
	    my @stat = stat($filename);
	    if (scalar(@stat)) {
		my $mtime = $stat[9];
		$before = $mtime if (!$before);
		$after = $mtime if (!$after);
		$result = 1 if ($mtime >= $after && $mtime <= $before);
	    }
	    return $result;
	}

	foreach my $key (sort {
	    my $ret = scalar(@{$b->{"keys"}}) <=> scalar(@{$a->{"keys"}});
	    if ($ret == 0) {
		my $val_a = $self->lookup($a);
		my $val_b = $self->lookup($b);
		$ret = $val_a->{"complexity"} <=> $val_b->{"complexity"};
		if ($ret == 0) {
		    $ret = $val_a->{"count"} <=> $val_b->{"count"};
		}
	    }
	    return $ret;
			 } @match_keys) {
	    my $val = $self->lookup($key);
	    my $ltreat;

	    my $ref = ref($val);
	    if ($ref eq "CODE") {
		$ltreat = $val->($key, $val);
	    } elsif ($ref eq "HASH") {
		$ltreat = eval $val->{"treat"};
	    } else {
		$ltreat = eval $val;
	    }

	    if (!defined($ltreat)) {
		$ltreat = 0;
		warn "$module: treat undefned, setting to 0";
	    }
	    if (!defined($t_key)) {
		$t_key = $key;
		$t_val = $val;
		$treat = $ltreat;
	    } else {
		if ($treat != $ltreat) {
		    my $t_depth = scalar(@{$t_key->{"keys"}});
		    my $v_depth = scalar(@{$key->{"keys"}});
		    my $t_complexity = $t_val->{"complexity"};
		    my $v_complexity = $val->{"complexity"};
		    my $t_count = $t_val->{"count"};
		    my $v_count = $val->{"count"};
		    if ($t_depth < $v_depth ||
			($t_depth == $v_depth && 
			 ($t_complexity > $v_complexity ||
			  ($t_complexity == $v_complexity &&
			   $t_count >= $v_count)))) {
			my $t_key_str = $t_key->to_string();
			my $key_str = $key->to_string();
			warn "$module: conflicting values ($treat, $ltreat) for keys ($t_key_str, $key_str";
		    }
		}
	    }
	}
	return { treat => $treat, key => $t_key };
    }
    1;
}

sub mkpath_err
{
    my $dstdir = shift;
    my @errors;
    my $ret;
    my $errlist;

    mkpath($dstdir, { error => \$errlist });
    if ($errlist && @$errlist) {
	for my $diag (@$errlist) {
	    my ($file, $message) = %$diag;
	    if ($file eq '') {
		push @errors, $message;
	    } else {
		push @errors, "$file: $message";
	    }
	}
    }
    return (@errors);
}

sub splitdir_no_empty
{
    my $directories = shift;

    my @results = splitdir( $directories );
    if (scalar(@results) > 0 && $results[$#results] eq '') {
	pop(@results);
    }
    return @results;
}

sub copy_dir_selected
{
    my ($srcdir, $dstdir, $ospec) = @_;
    my $srclength = length($srcdir);
    my $no_file = 1;
    my $yes_file = 0;
    my @dirs = ($dstdir);
    my $hhspec = FileTree->new($srcdir, $dstdir, $ospec);
    my $debug = $hhspec->{"debug"};
    my $module = "copy_dir_selected";

    my %options = (
	no_chdir => 1,
	preprocess => sub {
	    my @fdlist = @_;
	    my $src_name = $File::Find::name;
	    my $relpath;
	    if (length($src_name) <= $srclength) {
		$relpath = '';
	    } else {
		$relpath = substr($src_name, $srclength);
	    }
	    my($volume, $directories, $file) = splitpath($relpath, $yes_file);
	    my @srcdirs = splitdir_no_empty( $directories );

	    # &wanted() actually gets called twice:
	    #  - once to determine if we should prune directories,
	    #  - after &preprocess() to actually do something with the files.
	    # It sets the prune flag to 0 just before the pruning call.
	    # Set the flag to another distinguished value after preprocessing
	    #  so we can determine which call to &wanted() we're dealing with.
	    $File::Find::prune = 2;
	    @fdlist;
	},

	wanted => sub {
	    # This will be called prior to calling the preprocess sub
	    #  to potentially prune directories if $bydepth isn't set.
	    my $src_name = $File::Find::name;
	    my $src_dir = $File::Find::dir;
	    my $relpath;
	    if (length($src_name) <= $srclength) {
		$relpath = '';
	    } else {
		$relpath = substr($src_name, $srclength);
	    }
	    my ($volume, $directories, $file);
	    my @srcdirs;
	    my $sfpath;
	    my $pruning;
	    if ($File::Find::prune == 0) {
		$pruning = 1;
	    } else {
		$pruning = 0;
	    }

	    if ($relpath eq '') {
		# We're at the top level.
		# We've already created the top level destination directory
		return;
	    }

	    ($volume, $directories, $file) = splitpath($relpath, $pruning);
	    @srcdirs = splitdir_no_empty( $directories );
	    $sfpath = SFPath->new(\@srcdirs, $file);

	    my @matches = $hhspec->find_matches($sfpath);
	    my $treat = $hhspec->do_treat($sfpath, @matches);
	    my $t_file = $sfpath->to_string();
	    my $t_key = $treat->{"key"}->to_string();
	    if (!$treat->{"treat"} ) {
		# We don't want this file/directory. Prune it
		$File::Find::prune = 1 if ($pruning);
		my $skip_type = "skip";
		$skip_type = "prune" if ($pruning);
		print("$t_file\t$t_key\t$skip_type\n") if ($debug);
		return;
	    }
	    
	    # We want this file/directory.
	    # If it is a directory, make sure it exists in the destination tree.
	    my @ldirs = ($dstdir, @srcdirs );
	    my $ldstdir = catdir(@ldirs);
	    my $dst_name = catpath('', $ldstdir, $file);

	    my @file_stat = lstat($src_name);
	    if (-l) {
		return;
	    } elsif (-d) {
		if (!-d $dst_name) {
		    my @errlist = mkpath_err($dst_name);
		    if (@errlist) {
			warn join("\n", @errlist);
		    } else {
			print("$t_file\t$t_key\tmkpath\t$dst_name\n") if ($debug);
		    }
		} else {
		    print("$t_file\t$t_key\texists\t$dst_name\n") if ($debug);
		}
	    } elsif (-f) {
		# We currently copy zero length files (!-s).
		if (!copy($src_name, $dst_name)) {
		    warn "Couldn't copy($src_name, $dst_name): $!";
		} elsif (!utime($file_stat[8], $file_stat[9], $dst_name)) {
		    warn "Couldn't utime($dst_name): $!";
		} else {
		    print("$t_file\t$t_key\tcopy to\t$dst_name\n") if ($debug);
		}
	    } else {
		print("$t_file\t$t_key\tunrecognized\n") if ($debug);
	    }
	},
	
	);
    # Do we need to create a new top level directory?
    if (substr($srcdir, -1) ne '/') {
	# Yes. Create a new top level directory.
	my ($volume, $directories, $file) = splitpath($srcdir, $yes_file);
	$dstdir = catdir( ($dstdir, $file) );
	$srcdir .= '/';
	$srclength = length($srcdir);
    }

    if (! -d $dstdir) {
	my @errlist = mkpath_err($dstdir);
	if (@errlist) {
	    warn join("\n", @errlist);
	}
    }
    find(\%options, $srcdir);
}

if (0) {
    my $run_setup_start_time = time() - 60*60*2;
    my %dummy = (
	qr(/*.*/?) => 1,		# default, install everything
	qr(\.install-backup) => 0,
	qr(template.d) => {
	    qr(dumptypes.install-backup) => 1
	}
	);

    my %cores = (
	qr(/*.*/?) => 0,		# default, don't copy anything
	qr(/*.+\.core) => 'modified_between($self, $sfpath, ' . $run_setup_start_time . ', undef)'
	);
    my $hh = HierHash->new(\%dummy);
    my $hk = FTKey->new(qr(template.d/));
    my $val = $hh->lookup($hk);
    my @keys = $hh->keys();
    my @values = $hh->values();
    while (my ($k, $v) = $hh->each()) {
	print("$k: $v \n");
    }
    #copy_dir_selected("../prefix/etc/amanda", "../tmp/0_setupcache", \%dummy);
    copy_dir_selected("../tmp/", "/tmp/cores", \%cores);
} elsif (1) {
    my $run_setup_start_time = time() - 60*60*2;
    my %tmp = (
	qr(/*.*/?) => 0,		# default, don't copy anything
	qr(installchecks/) => {
	    qr(((holding)|(infodir)|(vtapes.*)|(TESTCONF))/) => {	# anything under holding, infodir, vtapes*, TESTCONF in tmp/installchecks
		qr(/*.*/?) => 'modified_between($self, $sfpath, ' . $run_setup_start_time . ', undef)'
	    }
	},
	qr(((server)|(client)|(amandad)|(log.error))/) => {	# anything under server, client, amandad, log.error in tmp
	    qr(/*.*/?) => 'modified_between($self, $sfpath, ' . $run_setup_start_time . ', undef)'
	}
	);
    my $sfpath = SFPath->new(["installchecks", "vtapes", "slot1"], "00000.TESTCONF01");
    my $ft = FileTree->new(".", "/tmp", \%tmp);
    my @matches = $ft->find_matches($sfpath);
    my ($mkey, $treat) = $ft->do_treat($sfpath, @matches);
}
1;
