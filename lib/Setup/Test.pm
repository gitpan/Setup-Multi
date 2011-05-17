package Setup::Test;
BEGIN {
  $Setup::Test::VERSION = '0.01';
}
# ABSTRACT: Various simple setup routines for testing

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(setup_text_case);

our %SPEC;

$SPEC{setup_text_case} = {
    summary  => "Change text case",
    description => <<'_',

On do, will change text case to UPPER/lower/Title Case. Will save the original
text for undo.

On undo, will restore the original text.

_
    args => {
        text_ref => ['str*' => { # XXX actually ref to str, not str
            summary => 'Reference to text',
        }],
        case => ['str*' => {
            summary => 'Case style',
            in => [qw/upper lower title/],
        }],
    },
    features => {undo=>1, dry_run=>1},
};
sub setup_text_case {
    my %args           = @_;
    my $dry_run        = $args{-dry_run};
    my $undo_action    = $args{-undo_action} // "";

    # check args
    my $text_ref       = $args{text_ref};
    defined($text_ref) or return [400, "Please specify text_ref"];
    ref($text_ref) eq 'SCALAR'
        or return [400, "Invalid text_ref: must be ref to a scalar"];
    my $case           = $args{case};
    $case or return [400, "Please specify case"];
    $case =~ /\A(upper|lower|title)\z/
        or return [400, "Invalid case: must be upper/lower/title"];

    # collect steps
    my $steps;
    if ($undo_action eq 'undo') {
        $steps = $args{-undo_data} or return [400, "Please supply -undo_data"];
    } else {
        $steps = [["case", $case]];
    }

    return [400, "Invalid steps, must be an array"]
        unless $steps && ref($steps) eq 'ARRAY';

    my $save_undo = $undo_action ? 1:0;

    # perform the steps
    my $rollback;
    my $undo_steps = [];
    my $changed;
  STEP:
    for my $i (0..@$steps-1) {
        my $step = $steps->[$i];
        $log->tracef("step %d of 0..%d: %s", $i, @$steps-1, $step);
        my $err;
        return [400, "Invalid step (not array)"] unless ref($step) eq 'ARRAY';

        if ($step->[0] eq 'case') {
            my $correct;
            if ($step->[1] eq 'upper') {
                $correct = uc($$text_ref);
            } elsif ($step->[1] eq 'title') {
                $correct = lc($$text_ref);
            } elsif ($step->[1] eq 'title') {
                ($correct = $$text_ref) =~ s/\b(\w)(\w*)\b/uc($1).lc($2)/eg;
            }
            if ($correct ne $$text_ref) {
                $log->tracef("nok: text case needs correcting");
                return [200, "Dry run"] if $dry_run;
                $changed++;
                unshift @$undo_steps, ["set", $$text_ref];
                $$text_ref = $correct;
                last;
            }
        } elsif ($step->[0] eq 'set') {
            return [200, "Dry run"] if $dry_run;
            $changed++;
            unshift @$undo_steps, ["case", $case];
            $$text_ref = $step->[1];
            last;
        } else {
            die "BUG: Unknown step command: $step->[0]";
        }
      CHECK_ERR:
        if ($err) {
            if ($rollback) {
                die "Failed rollback step $i of 0..".(@$steps-1).": $err";
            } else {
                $log->tracef("Step failed: $err, performing rollback (%s)...",
                             $undo_steps);
                $rollback = $err;
                $steps = $undo_steps;
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

Setup::Test - Various simple setup routines for testing

=head1 VERSION

version 0.01

=head1 SYNOPSIS

 use Setup::Unix::Group 'setup_text_case';

 # simple usage (doesn't save undo data)
 my $text = 'foo bar baz';
 my $res = setup_text_case text_ref => \$text, case => 'upper';
 die unless $res->[0] == 200 || $res->[0] == 304;

 # perform setup and save undo data (undo data should be serializable)
 $res = setup_text_case ..., -undo_action => 'do';
 die unless $res->[0] == 200 || $res->[0] == 304;
 my $undo_data = $res->[3]{undo_data};

 # perform undo
 $res = setup_text_case ..., -undo_action => "undo", -undo_data=>$undo_data;
 die unless $res->[0] == 200 || $res->[0] == 304;

=head1 DESCRIPTION

This module provides simple setup functions, useful for testing purposes.

This module is part of the Setup modules family.

This module uses L<Log::Any> logging framework.

This module's functions have L<Sub::Spec> specs.

=head1 THE SETUP MODULES FAMILY

I use the C<Setup::> namespace for the Setup modules family. See L<Setup::File>
for more details on the goals, characteristics, and implementation of Setup
modules family.

=head1 FUNCTIONS

None are exported by default, but they are exportable.

=head2 setup_text_case(%args) -> [STATUS_CODE, ERR_MSG, RESULT]


Change text case.

On do, will change text case to UPPER/lower/Title Case. Will save the original
text for undo.

On undo, will restore the original text.

Returns a 3-element arrayref. STATUS_CODE is 200 on success, or an error code
between 3xx-5xx (just like in HTTP). ERR_MSG is a string containing error
message, RESULT is the actual result.

This function supports undo operation. See L<Sub::Spec::Clause::features> for
details on how to perform do/undo/redo.

This function supports dry-run (simulation) mode. To run in dry-run mode, add
argument C<-dry_run> => 1.

Arguments (C<*> denotes required arguments):

=over 4

=item * B<case>* => I<str>

Value must be one of:

 ["upper", "lower", "title"]


Case style.

=item * B<text_ref>* => I<str>

Reference to text.

=back

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

