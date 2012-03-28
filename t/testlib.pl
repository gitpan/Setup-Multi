use 5.010;
use strict;
use warnings;

use File::chdir;
use File::Temp qw(tempdir);
use Setup::Multi qw(setup_multi);
use Test::More 0.96;
use Test::Setup qw(test_setup);

sub setup {
    $::tmp_dir = tempdir(CLEANUP => 1);
    $CWD = $::tmp_dir;

    diag "tmp dir = $::tmp_dir";
}

sub teardown {
    done_testing();
    if (Test::More->builder->is_passing) {
        #diag "all tests successful, deleting temp files";
        $CWD = "/";
    } else {
        diag "there are failing tests, not deleting temp files";
    }
}

sub test_setup_multi {
    my %tsmargs = @_;

    my %tsargs;
    for (qw/check_setup check_unsetup check_state1 check_state2
            name dry_do_error do_error set_state1 set_state2 prepare cleanup/) {
        $tsargs{$_} = $tsmargs{$_};
    }
    $tsargs{function} = \&setup_multi;

    my %fargs = %{ $tsmargs{args} };
    $tsargs{args} = \%fargs;

    test_setup(%tsargs);
}

1;
