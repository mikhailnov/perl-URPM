package URPM;

use strict;

#- prepare build of an hdlist from a list of files.
#- it can be used to start computing depslist.
#- parameters are :
#-   rpms     : array of all rpm file name to parse (mandatory)
#-   dir      : directory wich will contain headers (default to /tmp/.build_hdlist)
#-   callback : perl code to be called for each package read (default pack_header)
#-   clean    : bool to clean cache before (default no).
sub parse_rpms_build_headers {
    my ($urpm, %options) = @_;
    my ($dir, %cache, @headers, %names);

    #- check for mandatory options.
    if (@{$options{rpms} || []} > 0) {
	#- build a working directory which will hold rpm headers.
	$dir = $options{dir} || ($ENV{TMPDIR} || "/tmp") . "/.build_hdlist";
	$options{clean} and system(($ENV{LD_LOADER} ? ($ENV{LD_LOADER}) : ()), "rm", "-rf", $dir);
	-d $dir or mkdir $dir, 0755 or die "cannot create directory $dir\n";

	#- examine cache if it contains any headers which will be much faster to read
	#- than parsing rpm file directly.
	unless ($options{clean}) {
	    local *DIR;
	    opendir DIR, $dir;
	    while (my $file = readdir DIR) {
		$file =~ /(.+?-[^:\-]+-[^:\-]+\.[^:\-\.]+)(?::(\S+))?$/ or next;
		$cache{$2 || $1} = $file;
	    }
	    closedir DIR;
	}

	foreach (@{$options{rpms}}) {
	    my ($key) = /([^\/]*)\.rpm$/ or next; #- get rpm filename.
	    my ($id, $filename);

	    if ($cache{$key} && -s "$dir/$cache{$key}") {
		($id, undef) = $urpm->parse_hdlist("$dir/$cache{$key}", !$options{callback});
		defined $id or die "bad header $dir/$cache{$key}\n";
		$options{callback} and $options{callback}->($urpm, $id, %options);

		$filename = $cache{$key};
	    } else {
		($id, undef) = $urpm->parse_rpm($_);
		defined $id or die "bad rpm $_\n";
	
		my $pkg = $urpm->{depslist}[$id];

		$filename = $pkg->fullname;
		"$filename.rpm" eq $pkg->filename or $filename .= ":$key";

		print STDERR "$dir/$filename\n";
		unless (-s "$dir/$filename") {
		    local *F;
		    open F, ">$dir/$filename";
		    $pkg->build_header(fileno *F);
		    close F;
		}
		-s "$dir/$filename" or unlink("$dir/$filename"), die "can create header $dir/$filename\n";

		#- make smart use of memory (no need to keep header in memory now).
		if ($options{callback}) {
		    $options{callback}->($urpm, $id, %options);
		} else {
		    $pkg->pack_header;
		}
	    }

	    #- keep track of header associated (to avoid rereading rpm filename directly
	    #- if rereading has been made neccessary).
	    push @headers, $filename;
	}
    }
    @headers;
}

#- check if rereading of hdlist is neccessary.
sub unresolved_provides_clean {
    my ($urpm) = @_;
    my @unresolved = grep { ! defined $urpm->{provides}{$_} } keys %{$urpm->{provides} || {}};

    #- names can be safely removed in any cases.
    delete $urpm->{names};

    #- remove
    @{$urpm}{qw(depslist provides)} = ([], {});
    @{$urpm->{provides}}{@unresolved} = ();

    @unresolved;
}

#- read a list of headers (typically when building an hdlist when provides have
#- been cleaned.
#- parameters are :
#-   headers  : array of all headers file name to parse (mandatory)
#-   dir      : directory wich contains headers (default to /tmp/.build_hdlist)
#-   callback : perl code to be called for each package read (default pack_header)
sub parse_headers {
    my ($urpm, %options) = @_;
    my ($dir, $start, $id);

    $dir = $options{dir} || ($ENV{TMPDIR} || "/tmp") . "/.build_hdlist";
    -d $dir or die "no directory $dir\n";

    $start = @{$urpm->{depslist} || []};
    foreach (@{$options{headers} || []}) {
	#- make smart use of memory (no need to keep header in memory now).
	($id, undef) = $urpm->parse_hdlist("$dir/$_", !$options{callback});
	defined $id or die "bad header $dir/$_\n";
	$options{callback} and $options{callback}->($urpm, $id, %options);
    }
    defined $id ? ($start, $id) : ();
}

#- compute dependencies, result in stored in info values of urpm.
#- operations are incremental, it is possible to read just one hdlist, compute
#- dependencies and read another hdlist, and again.
#- parameters are :
#-   callback : callback to relocate reference to package id.
sub compute_deps {
    my ($urpm, %options) = @_;

    #- avoid recomputing already present infos, take care not to modify
    #- existing entries, as the array here is used instead of values of infos.
    my $start = @{$urpm->{deps} ||= []};
    my $end = $#{$urpm->{depslist} || []};

    #- check if something has to be done.
    $start > $end and return;

    #- take into account in which hdlist a package has been found.
    #- this can be done by an incremental take into account generation
    #- of depslist.ordered part corresponding to the hdlist.
    #- compute closed requires, do not take into account choices.
    foreach ($start .. $end) {
	my $pkg = $urpm->{depslist}[$_];

	my %required_packages;
	my @required_packages;
	my %requires; @requires{$pkg->requires_nosense} = ();
	my @requires = keys %requires;

	while (my $req = shift @requires) {
	    $req =~ /^basesystem/ and next; #- never need to requires basesystem directly as always required! what a speed up!
	    $req = ($req =~ /^\d+$/ && [ $req ] ||
		    $urpm->{provides}{$req} && [ keys %{$urpm->{provides}{$req}} ] ||
		    [ ($req !~ /NOTFOUND_/ && "NOTFOUND_") . $req ]);
	    if (@$req > 1) {
		#- this is a choice, no closure need to be done here.
		push @required_packages, $req;
	    } else {
		#- this could be nothing if the provides is a file not found.
		#- and this has been fixed above.
		foreach (@$req) {
		    my $pkg_ = /^\d+$/ && $urpm->{depslist}[$_];
		    exists $required_packages{$_} and next;
		    $required_packages{$_} = undef; $pkg_ or next;
		    foreach ($pkg_->requires_nosense) {
			unless (exists $requires{$_}) {
			    $requires{$_} = undef;
			    push @requires, $_;
			}
		    }
		}
	    }
	}
	#- examine choice to remove those which are not mandatory.
	foreach (@required_packages) {
	    unless (grep { exists $required_packages{$_} } @$_) {
		$required_packages{join '|', sort { $a <=> $b } @$_} = undef;
	    }
	}

	#- store a short representation of requires.
	$urpm->{requires}[$_] = join ' ', keys %required_packages;
    }

    #- expand choices and closure again.
    my %ordered;
    foreach ($start .. $end) {
	my @requires = ($_);
	my ($dep, %requires);
	while (defined ($dep = shift @requires)) {
	    exists $requires{$dep} || /^[^\d\|]*$/ and next;
	    foreach ($dep, split ' ', (defined $urpm->{deps}[$dep] ? $urpm->{deps}[$dep] : $urpm->{requires}[$dep])) {
		if (/\|/) {
		    push @requires, split /\|/, $_;
		} else {
		    /^\d+$/ and $requires{$_} = undef;
		}
	    }
	}

	my $pkg = $urpm->{depslist}[$_];
	my $delta = 1 + ($pkg->name eq 'basesystem' ? 10000 : 0) + ($pkg->name eq 'msec' ? 20000 : 0);
	foreach (keys %requires) {
	    $ordered{$_} += $delta;
	}
    }

    #- some package should be sorted at the beginning.
    my $fixed_weight = 10000;
    foreach (qw(basesystem msec * locales filesystem setup glibc sash bash libtermcap2 termcap readline ldconfig)) {
	foreach (keys %{$urpm->{provides}{$_} || {}}) {
	    /^\d+$/ and $ordered{$_} = $fixed_weight;
	}
	$fixed_weight += 10000;
    }
    foreach ($start .. $end) {
	my $pkg = $urpm->{depslist}[$_];

	$pkg->name =~ /locales-[a-zA-Z]/ and $ordered{$_} = 35000;
    }

    #- compute base flag, consists of packages which are required without
    #- choices of basesystem and are ALWAYS installed. these packages can
    #- safely be removed from requires of others packages.
    foreach (qw(basesystem glibc kernel)) {
	foreach (keys %{$urpm->{provides}{$_} || {}}) {
	    foreach ($_, split ' ', (defined $urpm->{deps}[$_] ? $urpm->{deps}[$_] : $urpm->{requires}[$_])) {
		/^\d+$/ and $urpm->{depslist}[$_] and $urpm->{depslist}[$_]->set_flag_base(1);
	    }
	}
    }

    #- give an id to each packages, start from number of package already
    #- registered in depslist.
    my %remap_ids; @remap_ids{sort {
	$ordered{$b} <=> $ordered{$a} or do {
	    my ($na, $nb) = map { $urpm->{depslist}[$_]->name } ($a, $b);
	    my ($sa, $sb) = map { /^lib(.*)/ and $1 } ($na, $nb);
	    $sa && $sb ? $sa cmp $sb : $sa ? -1 : $sb ? +1 : $na cmp $nb;
	}} ($start .. $end)} = ($start .. $end);

    #- recompute requires to use packages id, drop any base packages or
    #- reference of a package to itself.
    my @depslist;
    foreach ($start .. $end) {
	my $pkg = $urpm->{depslist}[$_];

	#- set new id.
	$pkg->set_id($remap_ids{$_});

	my ($id, $base, %requires_id, %not_founds);
	foreach (split ' ', $urpm->{requires}[$_]) {
	    if (/\|/) {
		#- all choices are grouped together at the end of requires,
		#- this allow computation of dropable choices.
		my ($to_drop, @choices_base_id, @choices_id);
		foreach (split /\|/, $_) {
		    my ($id, $base) = (exists $remap_ids{$_} ? $remap_ids{$_} : $_, $urpm->{depslist}[$_]->flag_base);
		    $base and push @choices_base_id, $id;
		    $base &&= ! $pkg->flag_base;
		    $to_drop ||= $id == $pkg->id || exists $requires_id{$id} || $base;
		    push @choices_id, $id;
		}

		#- package can safely be dropped as it will be selected in requires directly.
		$to_drop and next;

		#- if a base package is in a list, keep it instead of the choice.
		if (@choices_base_id) {
		    @choices_id = @choices_base_id;
		    $base = 1;
		}
		if (@choices_id == 1) {
		    $id = $choices_id[0];
		} else {
		    my $choices_key = join '|', sort { $a <=> $b } @choices_id;
		    $requires_id{$choices_key} = undef;
		    next;
		}
	    } elsif (/^\d+$/) {
		($id, $base) =  (exists $remap_ids{$_} ? $remap_ids{$_} : $_, $urpm->{depslist}[$_]->flag_base);
	    } else {
		$not_founds{$_} = undef;
		next;
	    }

	    #- select individual package from choices or defined package.
	    $base &&= ! $pkg->flag_base;
	    $base || $id == $pkg->id or $requires_id{$id} = undef;
	}
	#- be smart with memory usage.
	delete $urpm->{requires}[$_];
	$urpm->{deps}[$remap_ids{$_}] = join ' ', ((sort { ($a =~ /^(\d+)/)[0] <=> ($b =~ /^(\d+)/)[0] } keys %requires_id),
						   keys %not_founds);
	$depslist[$remap_ids{$_}-$start] = $pkg;
    }

    #- remap all provides ids for new package position and update depslist.
    delete $urpm->{requires};
    @{$urpm->{depslist}}[$start .. $end] = @depslist;
    foreach my $h (values %{$urpm->{provides}}) {
	my %provided;
	foreach (keys %{$h || {}}) {
	    $provided{exists $remap_ids{$_} ? $remap_ids{$_} : $_} = delete $h->{$_};
	}
	$h = \%provided;
    }
    $options{callback} and $options{callback}->($urpm, \%remap_ids, %options);

    ($start, $end);
}

#- build an hdlist from existing depslist, from start to end inclusive.
#- parameters are :
#-   hdlist   : hdlist file to use.
#-   dir      : directory wich contains headers (default to /tmp/.build_hdlist)
#-   start    : index of first package (default to first index of depslist).
#-   end      : index of last package (default to last index of depslist).
#-   ratio    : compression ratio (default 4).
#-   split    : split ratio (default 400000).
sub build_hdlist {
    my ($urpm, %options) = @_;
    my ($dir, $start, $end, $ratio, $split);

    $dir = $options{dir} || ($ENV{TMPDIR} || "/tmp") . "/.build_hdlist";
     -d $dir or die "no directory $dir\n";

    $start = $options{start} || 0;
    $end = $options{end} || $#{$urpm->{depslist}};

    #- compression ratio are not very high, sample for cooker
    #- gives the following (main only and cache fed up):
    #- ratio compression_time  size
    #-   9       21.5 sec     8.10Mb   -> good for installation CD
    #-   6       10.7 sec     8.15Mb
    #-   5        9.5 sec     8.20Mb
    #-   4        8.6 sec     8.30Mb   -> good for urpmi
    #-   3        7.6 sec     8.60Mb
    $ratio = $options{ratio} || 4;
    $split = $options{split} || 400000;

    open B, "| " . ($ENV{LD_LOADER} || '') . " packdrake -b${ratio}ds '$options{hdlist}' '$dir' $split";
    foreach my $pkg (@{$urpm->{depslist}}[$start .. $end]) {
	my $filename = $pkg->fullname;
	"$filename.rpm" ne $pkg->filename && $pkg->filename =~ /([^\/]*)\.rpm$/ and $filename .= ":$1";
	-s "$dir/$filename" or die "bad header $dir/$filename\n";
	print B "$filename\n";
    }
    close B or die "packdrake failed\n";
}

#- build synthesis file.
#- parameters are :
#-   synthesis : synthesis file to create (mandatory if fd not given).
#-   fd        : file descriptor (mandatory if synthesis not given).
#-   dir       : directory wich contains headers (default to /tmp/.build_hdlist)
#-   start     : index of first package (default to first index of depslist).
#-   end       : index of last package (default to last index of depslist).
#-   ratio     : compression ratio (default 9).
sub build_synthesis {
    my ($urpm, %options) = @_;
    my ($start, $end, $ratio);

    $start = $options{start} || 0;
    $end = $options{end} || $#{$urpm->{depslist}};
    $start > $end and return;
    $ratio = $options{ratio} || 9;
    $options{synthesis} || defined $options{fd} or die "invalid parameters given";

    #- first pass: traverse provides to find files provided.
    my %provided_files;
    foreach (keys %{$urpm->{provides}}) {
	/^\// or next;
	foreach my $id (keys %{$urpm->{provides}{$_} || {}}) {
	    push @{$provided_files{$id} ||= []}, $_;
	}
    }


    #- second pass: write each info including files provided.
    local *F;
    $options{synthesis} and open F, "| " . ($ENV{LD_LOADER} || '') . " gzip -$ratio >'$options{synthesis}'";
    foreach ($start .. $end) {
	my $pkg = $urpm->{depslist}[$_];
	my %files;

	if ($provided_files{$_}) {
	    @files{@{$provided_files{$_}}} = undef;
	    delete @files{$pkg->provides_nosense};
	}

	$pkg->build_info($options{synthesis} ? fileno *F : $options{fd}, join('@', keys %files));
    }
    close F;
}

#- write depslist.ordered file according to info in params.
#- parameters are :
#-   depslist : depslist.ordered file to create.
#-   provides : provides file to create.
#-   compss   : compss file to create.
sub build_base_files {
    my ($urpm, %options) = @_;
    local *F;

    if ($options{depslist}) {
	open F, ">$options{depslist}";
	for (0 .. $#{$urpm->{depslist}}) {
	    my $pkg = $urpm->{depslist}[$_];

	    printf F ("%s-%s-%s.%s%s %s %s\n", $pkg->fullname,
		      ($pkg->epoch ? ':' . $pkg->epoch : ''), $pkg->size || 0, $urpm->{deps}[$_]);
	}
	close F;
    }

    if ($options{provides}) {
	open F, ">$options{provides}";
	while (my ($k, $v) = each %{$urpm->{provides}}) {
	    printf F "%s\n", join '@', $k, map { scalar $urpm->{depslist}[$_]->fullname } keys %{$v || {}};
	}
	close F;
    }

    if ($options{compss}) {
	my %p;

	open F, ">$options{compss}";
	foreach (@{$urpm->{depslist}}) {
	    $_->group or next;
	    push @{$p{$_->group} ||= []}, $_->name;
	}
	foreach (sort keys %p) {
	    print F $_, "\n";
	    foreach (@{$p{$_}}) {
		print F "\t", $_, "\n";
	    }
	    print F "\n";
	}
	close F;
    }

    1;
}

1;
