#!perl

# test that setup_multi() uses caller package to qualify unqualified sub name

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Setup::File::Dir qw(setup_dir);
use Test::More 0.96;
require "testlib.pl";

use vars qw($tmp_dir);

setup();

*Test::Setup::setup_dir = \&setup_dir;

test_setup_multi(
    name          => "unqualified sub from caller",
    args          => {
        subs => [
            "setup_dir" => [
                {path=>"$tmp_dir/dir1",      should_exist=>1},
            ]],
    },
    check_unsetup => sub {
        ok(!(-d "$tmp_dir/dir1"), "dir1 doesn't exist");
    },
    check_setup   => sub {
        ok((-d "$tmp_dir/dir1"), "dir1 exists");
    },
);

DONE_TESTING:
teardown();
