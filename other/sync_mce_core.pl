#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## Barrier synchronization example.
## https://en.wikipedia.org/wiki/Barrier_(computer_science)
##
## MCE's Sync implementation.
##
###############################################################################

use strict;
use warnings;

use MCE;
use Time::HiRes qw(time);

my $num_workers = 8;

sub user_func {
   my $id = MCE->wid;
   for (1 .. 400) {
      MCE->print("$_: $id\n");
      MCE->sync;
   }
}

my $start = time();

my $mce = MCE->new(
   max_workers => $num_workers,
   user_func   => \&user_func
)->run;

printf {*STDERR} "\nduration: %0.3f\n\n", time() - $start;

## Time taken from a 2.6 GHz machine running Mac OS X.
##
## threads::shared:   0.207s  threads
##   forks::shared:  36.426s  child processes
##     MCE::Shared:   0.353s  child processes
##        MCE Sync:   0.062s  child processes
##

