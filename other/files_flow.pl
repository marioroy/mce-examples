#!/usr/bin/env perl

use strict;
use warnings;

## Same logic as in files_mce.pl, but with the MCE::Flow and MCE::Shared.
## usage: ./files_flow.pl [ startdir [0|1] ]

use Time::HiRes 'sleep';

use MCE::Flow   1.818;
use MCE::Shared 1.814;

my $D = MCE::Shared->queue( queue => [ $ARGV[0] || '.' ] );
my $F = MCE::Shared->queue( fast  => defined $ARGV[1] ? $ARGV[1] : 1 );

## Glob() is not thread-safe in Perl 5.16.x; okay < 5.16, fixed in 5.18.2.
## Not all OS vendors have patched 5.16.x.

my $providers = ($INC{'threads.pm'} && ($] >= 5.016000 && $] < 5.018002)) ? 1 : 2;
my $consumers = 6;

MCE::Flow::init {
   task_end => sub {
      my ($mce, $task_id, $task_name) = @_;
      $F->end() if ($task_name eq 'dir');
   }
};

## Override any MCE options and run. Notice how max_workers and
## task_name take an anonymous array to configure both tasks.

mce_flow {
   max_workers => [ $providers, $consumers ],
   task_name   => [ 'dir', 'file' ]
},
sub {
   ## Dir Task. Allow time for wid 1 to enqueue any dir entries.
   ## Otherwise, workers (wid 2+) may terminate early.
   sleep 0.15 if MCE->task_wid > 1;

   ## Include dot files; treat symbolic dirs as files.
   while (defined (my $dir = $D->dequeue_nb)) {
      my (@files, @dirs);

      foreach (glob("$dir/.??* $dir/*")) {
         if (-d $_ && ! -l $_) { push @dirs, $_; next; }
         push @files, $_;
      }

      $D->enqueue(@dirs ) if scalar @dirs;
      $F->enqueue(@files) if scalar @files;
   }
},
sub {
   ## File Task.
   while (defined (my $file = $F->dequeue)) {
      MCE->say($file);
   }
};

## Workers persist in models. This may be ommitted. It will run
## automatically during exiting if not already called.

MCE::Flow::finish;

