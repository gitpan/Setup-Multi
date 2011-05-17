#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib $Bin, "$Bin/t";

use Test::More 0.96;
require "testlib.pl";

use vars qw($undo_data $redo_data);

setup();

my $text        = "lower UPPER Title OtHer";
my $orig_text   = $text;
my $text_u      = "UPPER";
my $orig_text_u = $text_u;

test_setup_text_case(
    name       => "upper (already correct)",
    args       => {text_ref=>\$text_u, case=>'upper'},
    status     => 304,
    text       => $orig_text_u,
);

test_setup_text_case(
    name       => "upper (dry run)",
    args       => {text_ref=>\$text, case=>'upper', -dry_run=>1},
    status     => 200,
    text       => $orig_text,
);
test_setup_text_case(
    name       => "upper (with undo)",
    args       => {text_ref=>\$text, case=>'upper', -undo_action=>'do'},
    status     => 200,
    text       => uc($orig_text),
    posttest   => sub {
        my $res = shift;
        $undo_data = $res->[3]{undo_data};
        ok($undo_data, "there is undo data");
    },
);
test_setup_text_case(
    name       => "upper (undo, dry_run)",
    args       => {text_ref=>\$text, case=>'upper', -dry_run=>1,
                   -undo_action=>'undo', -undo_data=>$undo_data},
    status     => 200,
    text       => uc($orig_text),
);
test_setup_text_case(
    name       => "upper (undo)",
    args       => {text_ref=>\$text, case=>'upper',
                   -undo_action=>'undo', -undo_data=>$undo_data},
    status     => 200,
    text       => $orig_text,
    posttest   => sub {
        my $res = shift;
        $redo_data = $res->[3]{undo_data};
    },
);
test_setup_text_case(
    name       => "upper (redo, dry_run)",
    args       => {text_ref=>\$text, case=>'upper', -dry_run=>1,
                   -undo_action=>'undo', -undo_data=>$redo_data},
    status     => 200,
    text       => $orig_text,
);
test_setup_text_case(
    name       => "upper (redo)",
    args       => {text_ref=>\$text, case=>'upper',
                   -undo_action=>'undo', -undo_data=>$redo_data},
    status     => 200,
    text       => uc($orig_text),
);

# XXX: test case: lower
# XXX: test case: title

DONE_TESTING:
teardown();
