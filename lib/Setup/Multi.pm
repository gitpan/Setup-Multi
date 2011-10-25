package Setup::Multi;
{
  $Setup::Multi::VERSION = '0.05';
}
# ABSTRACT: Setup using a series of other setup routines

use 5.010;
use strict;
use warnings;
use Data::Dump::OneLine qw(dump1);
use Log::Any '$log';

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(setup_multi);

our %SPEC;

$SPEC{setup_multi} = {
    summary  => "Setup using a series of other setup routines",
    description => <<'_',

Accept a list of setup subroutine name and arguments, or coderefs, and call them
each sequentially as steps. If one step fails, the whole steps will be rolled
back using the undo data. If all steps succeed, return the concatenated undo
data from each step.

This function is declared as supporting the 'undo' and 'dry_run' features, so
all setup routines mentioned in 'subs' argument must also support those two
features (but this is not currently checked).

_
    args => {
        subs => ['array*' => {
            summary => 'List of setup subroutine (names/refs) and arguments',
            description => <<'_',

Setup subroutine can be a string (its name) or a coderef. If subroutine is a
non-qualified name (i.e., foo instead of Package::foo), it will be qualified
with caller's package. Argument can be a single hashref or arrayref (of
hashrefs). Example, if subs are:

 [
   'Pkg::func1'  => \%args,
   'func2'       => [\%args2, \%args3, \%args4],
   \&func3       => [\%args5],
   sub{...}      => \%args6,
 ]

then the subs which will be called:

 Pkg::func1->(%args);
 func2->(%args2);
 func2->(%args3);
 func2->(%args4);
 func3(%args5);
 (sub{...})->(%args6);

_
        }],
    },
    features => {undo=>1, dry_run=>1},
};
sub setup_multi {
    my %args           = @_;
    my $dry_run        = $args{-dry_run};
    my $undo_action    = $args{-undo_action} // "";

    # check args
    my $subs           = $args{subs};
    $subs or return [400, "Please specify subs"];
    ref($subs) eq 'ARRAY' or return [400, "Invalid subs: must be array"];
    @$subs % 2 and return [400, "Invalid subs: odd number of elements"];

    # collect steps
    my $steps;
    if ($undo_action eq 'undo') {
        $steps = $args{-undo_data} or return [400, "Please supply -undo_data"];
    } else {
        $steps = [];
        my @subs = @$subs;
        my $i = 0;
        while (my ($s, $a) = splice @subs, 0, 2) {
            $i++;
            my $sref;
            if (!defined($s)) {
                return [400, "#$i: Function not defined"]
            } if (!ref($s)) {
                return [400, "Invalid function syntax $s"]
                    unless $s =~ /\A\w+(?:::\w+)*\z/;
                if ($s !~ /::/) { # not qualified
                    my $callpkg = caller();
                    $s = "$callpkg\::$s";
                }
                return [400, "#$i: Function $s doesn't exist"]
                    unless defined(&{$s});
                $sref = \&{$s};
            } elsif (ref($s) eq 'CODE') {
                # XXX also check whether it's a valid coderef
                $sref = $s;
            } else {
                return [400, "#$i: subroutine needs to be string/coderef"];
            }
            my @a;
            if (ref($a) eq 'ARRAY') {
                @a = @$a;
            } else {
                @a = ($a);
            }
            for (@a) {
                return [400, "#$i: arrayref argument contains a nonhash"]
                    unless ref($_) eq 'HASH';
                push @$steps, ["do", $s, $_];
            }
        }
    }

    return [400, "Invalid steps, must be an array"]
        unless $steps && ref($steps) eq 'ARRAY';

    my $save_undo = $undo_action ? 1:0;

    # perform the steps
    my $rollback;
    my $changed;
    my $undo_steps = [];
  STEP:
    for my $i (0..@$steps-1) {
        my $step = $steps->[$i];
        $log->tracef("step %d/%d: %s", $i+1, scalar @$steps, $step);
        my $err;
        return [400, "Invalid step (not array)"] unless ref($step) eq 'ARRAY';

        if ($step->[0] =~ /\A(do|undo)\z/) {
            my ($sub, $sub_args) = ($step->[1], $step->[2]);
            my $subref = ref($sub) eq 'CODE' ? $sub : \&{$sub};
            my %sub_args = %$sub_args;
            $sub_args{-undo_action} = $step->[0];
            $sub_args{-undo_data}   = $step->[3] if $step->[0] eq 'undo';
            $sub_args{-dry_run}     = $dry_run;
            $log->tracef("Calling %s(%s) ...", $sub, \%sub_args);
            my $res = $subref->(%sub_args);
            if ($res->[0] == 200) {
                $changed++;
            } elsif ($res->[0] != 304) {
                $err = sprintf "(failure in step %d/%d: %s(%s)) %d - %s",
                    $i+1, scalar @$steps, $sub, dump1(\%sub_args), 
		        $res->[0], $res->[1];
                goto CHECK_ERR;
            }
            unshift @$undo_steps,
                ["undo", $sub, $sub_args,
                 $res->[3] ? $res->[3]{undo_data} : undef];
        } else {
            die "BUG: Unknown step command: $step->[0]";
        }
      CHECK_ERR:
        if ($err) {
            if ($rollback) {
                die sprintf "Failed rollback step %d/%d: %s",
                    $i+1, scalar @$steps, $err;
            } else {
                $log->tracef("Step failed: $err, performing rollback (%s)...",
                             $undo_steps);
                $rollback = $err;
                $steps = $undo_steps;
                $undo_steps = [];
                goto STEP; # perform steps all over again
            }
        }
    }
    return [500, "Error (rollbacked): $rollback"] if $rollback;

    my $data = undef;
    my $meta = {};
    $meta->{undo_data} = $undo_steps if $save_undo;
    $log->tracef("meta: %s", $meta);
    return [$changed? 200 : 304, $changed? "OK" : "Nothing done", $data, $meta];
}
1;


=pod

=head1 NAME

Setup::Multi - Setup using a series of other setup routines

=head1 VERSION

version 0.05

=head1 SYNOPSIS

 use Setup::Multi     'setup_multi';
 use Setup::File::Dir 'setup_dir';
 use Setup::File      'setup_file';

 # simple usage (doesn't save undo data)
 my $res = setup_multi
     subs => [
         setup_dir  => [{name=>'/foo',         should_exist=>1},
                        {name=>'/foo/bar',     should_exist=>1},
                        {name=>'/foo/bar/baz', should_exist=>1}],
         setup_file =>  {name=>"/foo/bar/baz/qux", should_exist=>1},
     ];
 die unless $res->[0] == 200 || $res->[0] == 304;

 # perform setup and save undo data (undo data should be serializable)
 $res = setup_multi ..., -undo_action => 'do';
 die unless $res->[0] == 200 || $res->[0] == 304;
 my $undo_data = $res->[3]{undo_data};

 # perform undo
 $res = setup_multi ..., -undo_action => "undo", -undo_data=>$undo_data;
 die unless $res->[0] == 200 || $res->[0] == 304;

=head1 DESCRIPTION

This module provides one function: B<setup_multi>.

This module is part of the Setup modules family.

This module uses L<Log::Any> logging framework.

This module's functions have L<Sub::Spec> specs.

=head1 THE SETUP MODULES FAMILY

I use the C<Setup::> namespace for the Setup modules family. See L<Setup::File>
for more details on the goals, characteristics, and implementation of Setup
modules family.

=head1 FUNCTIONS

None are exported by default, but they are exportable.

=head2 setup_multi(%args) -> [STATUS_CODE, ERR_MSG, RESULT]


Setup using a series of other setup routines.

Accept a list of setup subroutine name and arguments, or coderefs, and call them
each sequentially as steps. If one step fails, the whole steps will be rolled
back using the undo data. If all steps succeed, return the concatenated undo
data from each step.

This function is declared as supporting the 'undo' and 'dry_run' features, so
all setup routines mentioned in 'subs' argument must also support those two
features (but this is not currently checked).

Returns a 3-element arrayref. STATUS_CODE is 200 on success, or an error code
between 3xx-5xx (just like in HTTP). ERR_MSG is a string containing error
message, RESULT is the actual result.

This function supports undo operation. See L<Sub::Spec::Clause::features> for
details on how to perform do/undo/redo.

This function supports dry-run (simulation) mode. To run in dry-run mode, add
argument C<-dry_run> => 1.

Arguments (C<*> denotes required arguments):

=over 4

=item * B<subs>* => I<array>

List of setup subroutine (names/refs) and arguments.

Setup subroutine can be a string (its name) or a coderef. If subroutine is a
non-qualified name (i.e., foo instead of Package::foo), it will be qualified
with caller's package. Argument can be a single hashref or arrayref (of
hashrefs). Example, if subs are:

 [
   'Pkg::func1'  => \%args,
   'func2'       => [\%args2, \%args3, \%args4],
   \&func3       => [\%args5],
   sub{...}      => \%args6,
 ]

then the subs which will be called:

 Pkg::func1->(%args);
 func2->(%args2);
 func2->(%args3);
 func2->(%args4);
 func3(%args5);
 (sub{...})->(%args6);

=back

=head1 FAQ

=head2 When to use coderef (routine refs) or string (routine names) in subs?

Since the routine name is included in undo data, use string to make it easily
serializable.

=head1 SEE ALSO

Other modules in Setup:: namespace.

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__

