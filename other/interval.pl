#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## This example demonstrates the "interval" option in MCE.
##
## usage: interval.pl [ delay ]   ## Default is 0.1
##        interval.pl   0.005
##        interval.pl   1.000
##
###############################################################################

use strict;
use warnings;

my $prog_name = $0; $prog_name =~ s{^.*[\\/]}{}g;

use Time::HiRes 'time';
use MCE;

my $d = shift || 0.1;

local $| = 1;

###############################################################################
## ----------------------------------------------------------------------------
## User functions for MCE.
##
###############################################################################

sub create_task {

   my ($node_id) = @_;

   my $seq_size  = 6;
   my $seq_start = ($node_id - 1) * $seq_size + 1;
   my $seq_end   = $seq_start + $seq_size - 1;

   return {
      max_workers => 2, sequence => [ $seq_start, $seq_end ],
      interval => { delay => $d, max_nodes => 4, node_id => $node_id }
   };
}

sub user_begin {

   my ($mce, $task_id, $task_name) = @_;

   ## The yield method causes this worker to wait for its next
   ## time interval slot before running. Yield has no effect
   ## without the "interval" option.

   ## Yielding is beneficial inside a user_begin block. A use case
   ## is staggering database connections among workers in order
   ## to not impact the DB server.

   MCE->yield;

   MCE->printf(
      "Node %2d: %0.5f -- Worker %2d: %12s -- Started\n",
      MCE->task_id + 1, time, MCE->task_wid, ''
   );

   return;
}

{
   my $prev_time = time;

   sub user_func {

      my ($mce, $seq_n, $chunk_id) = @_;

      ## Yield simply waits for the next time interval.
      MCE->yield;

      ## Calculate how long this worker has waited.
      my $curr_time = time;
      my $time_waited = $curr_time - $prev_time;

      $prev_time = $curr_time;

      MCE->printf(
         "Node %2d: %0.5f -- Worker %2d: %12.5f -- Seq_N %3d\n",
         MCE->task_id + 1, time, MCE->task_wid, $time_waited, $seq_n
      );

      return;
   }
}

###############################################################################
## ----------------------------------------------------------------------------
## Simulate a 4 node environment passing node_id to create_task.
##
###############################################################################

print "Node_ID  Current_Time        Worker_ID  Time_Waited     Comment\n";

MCE->new(
   user_begin => \&user_begin,
   user_func  => \&user_func,

   user_tasks => [
      create_task(1),
      create_task(2),
      create_task(3),
      create_task(4)
   ]

)->run;

