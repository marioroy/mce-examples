#!/usr/bin/perl
###############################################################################
##
## Monitor script contributed by George Bouras (Greece 02/2015).
## A demonstration for MCE->enq and MCE->await in MCE 1.700.
##
###############################################################################

use strict;
use warnings;

use Time::HiRes 'sleep';
use MCE::Step fast => 1;

my %Monitors = (
   mon_cpu => [ qw/ srvC1 srvC2 srvC3 srvC4 srvC5 srvC6 srvC7 / ],
   mon_dsk => [ qw/ srvD1 srvD2 srvD3 srvD4 srvD5 srvD6 srvD7 / ],
   mon_mem => [ qw/ srvM1 srvM2 srvM3 srvC4 srvM5 srvM6 srvM7 / ]
);

## Checking frequency (in seconds) of every monitor.
## Using fractional seconds for this demonstration.

my %Schedules = (
   0.15 => [ qw/ mon_cpu mon_dsk / ],
   0.35 => [ qw/ mon_mem         / ]
);

###############################################################################
##
## Run 4 sub-tasks simultaneously using one MCE instance
##
###############################################################################

MCE::Step::run({
   task_name    => [ qw/ scheduler mon_cpu mon_dsk mon_mem / ],
   max_workers  => [ scalar keys %Schedules, 10, 10, 10 ],
   input_data   => [ sort { $a <=> $b } keys %Schedules ],
   chunk_size   => 1,

   user_begin   => sub { my ($mce, $task_id, $task_name) = @_; },
   user_end     => sub { my ($mce, $task_id, $task_name) = @_; },
   user_output  => sub { print STDOUT "$_[0]\n" },
   user_error   => sub { print STDERR "$_[0]\n" },

   spawn_delay  => 0,
   submit_delay => 0,
   job_delay    => 0,

}, \&Scheduler, \&Monitor, \&Monitor, \&Monitor);

MCE::Step::finish;

###############################################################################
##
## Sub-tasks for Many-Core Engine.
##
###############################################################################

sub Scheduler
{
   my ($mce, $chunk_ref, $chunk_id) = @_;

   my $worker_id = $mce->wid;
   my $seconds   = $chunk_ref->[0];
   my @WorkLoad;
   my $work_ref;

   ## change to while ('FOR EVER') if desired
   for (1 .. 10) {
      foreach my $mon (@{ $Schedules{$seconds} }) {

         $mce->print(
            "interval $seconds sec, starting monitors : " .
            "@{ $Schedules{$seconds} }"
         );

         ## send work to monitor task
         $mce->enq($mon, @{ $Monitors{$mon} });

         ## wait until time elapse
         sleep $seconds;

         ## continue waiting if not completed
         $mce->await($mon, 0);
      }
   }

   return;
}

sub Monitor
{
   my ($mce, $server) = @_;

   my $monitor   = $mce->task_name;
   my $worker_id = $mce->wid;

   MCE->print("monitor=$monitor , server=$server");

   return;
}

