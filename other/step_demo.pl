#!/usr/bin/env perl

use strict;
use warnings;

use MCE::Step;

## In the demonstration below, one may call ->gather or ->step any number
## of times although ->step is not allowed in the last sub-block. Data is
## gathered to @arr which may likely be out-of-order. Gathering data is
## optional. All sub-blocks receive $mce as the first argument.

## First, defining 3 sub-tasks.

sub task_a {
   my ($mce, $chunk_ref, $chunk_id) = @_;

   if ($_ % 2 == 0) {
      MCE->gather($_);
    # MCE->gather($_ * 4);        ## Ok to gather multiple times
   }
   else {
      MCE->print("a step: $_, $_ * $_\n");
      MCE->step($_, $_ * $_);
    # MCE->step($_, $_ * 4 );     ## Ok to step multiple times
   }
}

sub task_b {
   my ($mce, $arg1, $arg2) = @_;

   MCE->print("b args: $arg1, $arg2\n");

   if ($_ % 3 == 0) {             ## $_ is the same as $arg1
      MCE->gather($_);
   }
   else {
      MCE->print("b step: $_ * $_\n");
      MCE->step($_ * $_);
   }
}

sub task_c {
   my ($mce, $arg1) = @_;

   MCE->print("c: $_\n");
   MCE->gather($_);
}

## Next, pass MCE options, using chunk_size 1, and run all 3 tasks
## in parallel. Notice how max_workers can take an anonymous array,
## similarly to task_name.

my @arr = mce_step {
   task_name   => [ 'a', 'b', 'c' ],
   max_workers => [  2,   2,   2  ],
   chunk_size  => 1

}, \&task_a, \&task_b, \&task_c, 1..10;

## Finally, sort the array and display its contents.

@arr = sort { $a <=> $b } @arr;

print "\n@arr\n\n";

