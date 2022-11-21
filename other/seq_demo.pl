#!/usr/bin/env perl

use strict;
use warnings;

use MCE;
use Time::HiRes 'sleep';

## A demonstration applying sequences with user_tasks.
## Chunking can also be configured independently as well.

## Run with seq_demo.pl | sort

sub user_func {
   my ($mce, $seq_n, $chunk_id) = @_;

   my $wid      = MCE->wid;
   my $task_id  = MCE->task_id;
   my $task_wid = MCE->task_wid;

   if (ref $seq_n eq 'ARRAY') {
      ## seq_n or $_ is an array reference when chunk_size > 1
      foreach (@{ $seq_n }) {
         MCE->printf(
            "task_id %d: seq_n %s: chunk_id %d: wid %d: task_wid %d\n",
            $task_id,    $_,       $chunk_id,   $wid,   $task_wid
         );
      }
   }
   else {
      MCE->printf(
         "task_id %d: seq_n %s: chunk_id %d: wid %d: task_wid %d\n",
         $task_id,    $seq_n,   $chunk_id,   $wid,   $task_wid
      );
   }

   sleep 0.003;

   return;
}

## Each task can be configured uniquely.

my $mce = MCE->new(
   user_tasks => [{
      max_workers => 2,
      chunk_size  => 1,
      sequence    => { begin => 11, end => 19, step => 1 },
      user_func   => \&user_func
   },{
      max_workers => 2,
      chunk_size  => 5,
      sequence    => { begin => 21, end => 29, step => 1 },
      user_func   => \&user_func
   },{
      max_workers => 2,
      chunk_size  => 3,
      sequence    => { begin => 31, end => 39, step => 1 },
      user_func   => \&user_func
   }]
);

$mce->run;

