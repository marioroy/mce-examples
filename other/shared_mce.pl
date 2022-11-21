#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## This script, similar to the forseq.pl example as far as usage goes.
## Utilizes MCE::Shared to store results into a hash.
##
## usage: shared_mce.pl [ size ]
## usage: shared_mce.pl [ begin end [ step [ format ] ] ]
##
##   e.g. shared_mce.pl 10 20 2
##
## The format string is passed to sprintf (% is optional).
##
##   e.g. shared_mce.pl 20 30 0.2 %4.1f
##        shared_mce.pl 20 30 0.2  4.1f
##
###############################################################################

use strict;
use warnings;

use Time::HiRes qw(time);

use MCE::Loop;
use MCE::Shared;

my $prog_name = $0; $prog_name =~ s{^.*[\\/]}{}g;
my $s_begin   = shift || 3000;
my $s_end     = shift;
my $s_step    = shift || 1;
my $s_format  = shift;

if ($s_begin !~ /\A\d*\.?\d*\z/) {
   print {*STDERR} "usage: $prog_name [ size ]\n";
   print {*STDERR} "usage: $prog_name [ begin end [ step [ format ] ] ]\n";
   exit;
}

unless (defined $s_end) {
   $s_end = $s_begin - 1; $s_begin = 0;
}

###############################################################################
## ----------------------------------------------------------------------------
## Parallelize via MCE.
##
###############################################################################

MCE::Loop::init { chunk_size => 1, max_workers => 'auto' };

my $results = MCE::Shared->hash();
my $start = time;

mce_loop_s {
   $results->{$_} = sprintf "n: %s sqrt(n): %f\n", $_, sqrt($_);
} $s_begin, $s_end, $s_step, $s_format;

my $hashref = $results->destroy;

if ($s_begin <= $s_end) {
 # print $results->{$_} foreach (sort { $a <=> $b } keys %$results);
   print $hashref->{$_} foreach (sort { $a <=> $b } keys %$hashref);
} else {
 # print $results->{$_} foreach (sort { $b <=> $a } keys %$results);
   print $hashref->{$_} foreach (sort { $b <=> $a } keys %$hashref);
}

printf {*STDERR} "\n## Compute time: %0.03f\n\n", time - $start;

