#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Setup::File::Dir;
use Test::More 0.96;
require "testlib.pl";

use vars qw($tmp_dir $undo_data $redo_data);

setup();

test_setup_multi(
    name       => "dir(OK) + dir(OK) (dry run)",
    args       => {
        subs => [
            "Setup::File::Dir::setup_dir" => [
                {path=>"$tmp_dir/dir1",      should_exist=>1},
                {path=>"$tmp_dir/dir1/dir2", should_exist=>1}]],
        -dry_run=>1},
    status     => 200,
    posttest   => sub {
        my $res = shift;
        ok(!(-d "$tmp_dir/dir1"), "dir1 doesn't exist");
    },
);
test_setup_multi(
    name       => "dir(OK) + dir(OK) (with undo)",
    args       => {
        subs => [
            "Setup::File::Dir::setup_dir" => [
                {path=>"$tmp_dir/dir1",    should_exist=>1},
                {path=>"$tmp_dir/dir1/dir2", should_exist=>1}]],
        -undo_action=>'do'},
    status     => 200,
    posttest   => sub {
        my $res = shift;
        $undo_data = $res->[3]{undo_data};
        ok((-d "$tmp_dir/dir1"), "dir1 exists");
        ok((-d "$tmp_dir/dir1/dir2"), "dir1/dir2 exists");
    },
);
test_setup_multi(
    name       => "dir(OK) + dir(OK) (undo)",
    args       => {
        subs => [
            "Setup::File::Dir::setup_dir" => [
                {path=>"$tmp_dir/dir1",    should_exist=>1},
                {path=>"$tmp_dir/dir1/dir2", should_exist=>1}]],
        -undo_action=>'undo', -undo_data=>$undo_data},
    status     => 200,
    posttest   => sub {
        my $res = shift;
        $redo_data = $res->[3]{undo_data};
        ok(!(-d "$tmp_dir/dir1"), "dir1 doesn't exist");
    },
);
test_setup_multi(
    name       => "dir(OK) + dir(OK) (redo)",
    args       => {
        subs => [
            "Setup::File::Dir::setup_dir" => [
                {path=>"$tmp_dir/dir1",    should_exist=>1},
                {path=>"$tmp_dir/dir1/dir2", should_exist=>1}]],
        -undo_action=>'undo', -undo_data=>$redo_data},
    status     => 200,
    posttest   => sub {
        my $res = shift;
        ok((-d "$tmp_dir/dir1"), "dir1 exists");
        ok((-d "$tmp_dir/dir1/dir2"), "dir1/dir2 exists");
    },
);

test_setup_multi(
    name       => "dir(OK) + dir(F), rolled back",
    args       => {
        subs => [
            "Setup::File::Dir::setup_dir" => [
                {path=>"$tmp_dir/d1b",         should_exist=>1},
                {path=>"$tmp_dir/d1b/d2b/d3b", should_exist=>1}]],
        -undo_action=>'do'},
    status     => 500,
    posttest   => sub {
        my $res = shift;
        $undo_data = $res->[3]{undo_data};
        ok(!(-d "$tmp_dir/d1b"), "d1b doesn't exist");
    },
);

DONE_TESTING:
teardown();
