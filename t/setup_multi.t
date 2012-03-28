#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Setup::File::Dir;
use Test::More 0.96;
require "testlib.pl";

use vars qw($tmp_dir);
setup();

test_setup_multi(
    name          => "dir(OK) + dir(OK)",
    args          => {
        subs => [
            "Setup::File::Dir::setup_dir" => [
                {path=>"$tmp_dir/dir1",      should_exist=>1},
                {path=>"$tmp_dir/dir1/dir2", should_exist=>1}]],
    },
    check_unsetup => sub {
        ok(!(-d "$tmp_dir/dir1"), "dir1 doesn't exist");
    },
    check_setup   => sub {
        ok( (-d "$tmp_dir/dir1/dir2"), "dir2 exists");
    },
);
test_setup_multi(
    name       => "dir(OK) + dir(F) -> rolled back",
    args       => {
        subs => [
            "Setup::File::Dir::setup_dir" => [
                {path=>"$tmp_dir/d1b",             should_exist=>1},
                {path=>"$tmp_dir/d1b/2",           should_exist=>1},
                {path=>"$tmp_dir/d1b/2/3",         should_exist=>1},
                {path=>"$tmp_dir/d1b/2/3/4",       should_exist=>1},
                {path=>"$tmp_dir/d1b/2/3/4/5/6",   should_exist=>1}, # fail here
                {should_exist=>1}, # missing arg, reached upon dry-run
                {path=>"$tmp_dir/d1b/2/3/4/5/6/7", should_exist=>1},
            ]],
    },
    dry_do_error => 500,
    check_unsetup => sub {
        ok(!(-d "$tmp_dir/d1b"), "d1b doesn't exist");
    },
);
test_setup_multi(
    name       => "dir(OK) + dir(F) -> rolled back",
    args       => {
        subs => [
            "Setup::File::Dir::setup_dir" => [
                {path=>"$tmp_dir/d1b",             should_exist=>1},
                {path=>"$tmp_dir/d1b/2",           should_exist=>1},
                {path=>"$tmp_dir/d1b/2/3",         should_exist=>1},
                {path=>"$tmp_dir/d1b/2/3/4",       should_exist=>1},
                {path=>"$tmp_dir/d1b/2/3/4/5/6",   should_exist=>1}, # fail here
                {path=>"$tmp_dir/d1b/2/3/4/5/6/7", should_exist=>1}, # unreached
            ]],
    },
    do_error => 500,
    check_unsetup => sub {
        ok(!(-d "$tmp_dir/d1b"), "d1b doesn't exist");
    },
);

DONE_TESTING:
teardown();
