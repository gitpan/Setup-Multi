use 5.010;
use strict;
use warnings;

#use File::chdir;
#use File::Slurp;
#use File::Temp qw(tempdir);
use Setup::Test qw(setup_text_case);
use Test::More 0.96;

sub setup {
    #$::tmp_dir = tempdir(CLEANUP => 1);
    #$CWD = $::tmp_dir;

    #diag "tmp dir = $::tmp_dir";
}

sub teardown {
    done_testing();
    if (Test::More->builder->is_passing) {
        #diag "all tests successful, deleting temp files";
        #$CWD = "/";
    } else {
        #diag "there are failing tests, not deleting temp files";
    }
}

sub test_setup_text_case {
    my %args = @_;
    subtest "$args{name}" => sub {

        my %setup_args = %{ $args{args} };
        my $res;
        eval {
            $res = setup_text_case(%setup_args);
        };
        my $eval_err = $@;

        if ($args{dies}) {
            ok($eval_err, "dies");
        } else {
            ok(!$eval_err, "doesn't die") or diag $eval_err;
        }

        #diag explain $res;
        if ($args{status}) {
            is($res->[0], $args{status}, "status $args{status}")
                or diag explain($res);
        }
        if (defined $args{text}) {
            is(${$setup_args{text_ref}}, $args{text}, "text")
                or diag explain($res);
        }
        if ($args{posttest}) {
            $args{posttest}->($res);
        }
    };
}

1;
