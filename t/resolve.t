#!/usr/bin/perl

use strict ;
use warnings ;
use Test::More tests => 6;
use URPM;

chdir 't' if -d 't';

my $urpm;
my $db;

END {
    if($db) {
    	$db = URPM::DB::close($db);
    }
    system("rm -rf tmp"); 
}

sub solve_check {
    my ($pkg, $pkgtotal, $suggest, $write) = @_;
    my $cand_pkgs = $urpm->find_candidate_packages($pkg);
    my @pkgs;
    my $out;
    my $in = "";
    my $file = "res/$pkg.resolve";
    if ($suggest) {
	@pkgs = $urpm->resolve_requested($db, undef, $cand_pkgs);
	$file .= ".suggests";
    } else {
	@pkgs = $urpm->resolve_requested__no_suggests_($db, undef, $cand_pkgs);
	$file .= ".nosuggests";
    }
    foreach (@pkgs) {
	$out .= $_->fullname() . "\n";
    }
    if ($write) {
    	open FILE, ">$file";
	
    	print FILE  $out;
	close FILE;
    } else {
	open(my $diff, "echo -n '$out' | diff -pu $file - |") or die $!;
	while(<$diff>) {
	    $in .= <$diff>;

	}
	close($diff);
    }
    is($in, "", "$file comparision");

    is(int @pkgs, $pkgtotal, "$pkg total number of packages");
}

SKIP: {
    my $synthesis = "res/synthesis.hdlist.xz";

    if (!(-r $synthesis)) {
    	skip "$synthesis missing, only found in svn", 6;
    }
    $db = URPM::DB::open("tmp", 1);
    $urpm = new URPM;
    $urpm->parse_synthesis($synthesis);

    solve_check("basesystem-minimal", 141, 0, 0);
    solve_check("basesystem", 527, 1, 0);
    solve_check("task-kde4", 2059, 1, 0);
}
