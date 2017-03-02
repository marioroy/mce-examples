#!/usr/bin/env perl

use strict;
use warnings;

## usage: ./files_thr.pl [ startdir ]

use threads;
use threads::shared;

use Time::HiRes 'sleep';

use MCE 1.818;
use Thread::Queue;

my $D = Thread::Queue->new($ARGV[0] || '.');
my $F = Thread::Queue->new;

## Glob() is not thread-safe in Perl 5.16.x; okay < 5.16, fixed in 5.18.2.
## Not all OS vendors have patched 5.16.x.

my $providers = ($INC{'threads.pm'} && ($] >= 5.016000 && $] < 5.018002)) ? 1 : 3;
my $consumers = 8;

my $mce = MCE->new(

   task_end => sub {
      my ($mce, $task_id, $task_name) = @_;
      $F->end() if ($task_name eq 'dir');
   },

   user_tasks => [{
      max_workers => $providers, task_name => 'dir',

      user_func => sub {
         ## Allow time for wid 1 to enqueue any dir entries.
         ## Otherwise, workers (wid 2+) may terminate early.
         sleep 0.1 if MCE->task_wid > 1;

         while (defined (my $dir = $D->dequeue_nb)) {
            my (@files, @dirs); foreach (glob("$dir/*")) {
               if (-d $_) { push @dirs, $_; next; }
               push @files, $_;
            }
            $D->enqueue(@dirs ) if scalar @dirs;
            $F->enqueue(@files) if scalar @files;
         }
      }
   },{
      max_workers => $consumers, task_name => 'file',

      user_func => sub {
         while (defined (my $file = $F->dequeue)) {
            MCE->say($file);
         }
      }
   }]

)->run;

