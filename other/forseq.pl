#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## This example demonstrates the sqrt example from Parallel::Loops
## (Parallel::Loops v0.07 utilizing Parallel::ForkManager v1.07).
##
## Testing was on a Linux VM; Perl v5.16.3; Haswell i7 at 2.6 GHz.
## The number indicates the size of input displayed in 1 second.
## Output was directed to >/dev/null.
##
## Parallel::Loops:     1,600  Forking each @input is expensive
## MCE->foreach...:    50,000  Workers persist between each @input
## MCE->forseq....:   200,000  Uses sequence of numbers as input
## MCE->forchunk..:   800,000  IPC overhead is greatly reduced
##
## usage: forseq.pl [ size ]
## usage: forseq.pl [ begin end [ step [ format ] ] ]
##
##   The % character is optional for format.
##   forseq.pl 20 30 0.2 %4.1f
##   forseq.pl 20 30 0.2  4.1f
##
###############################################################################

use strict;
use warnings;

use Time::HiRes qw(time);
use MCE;

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
## Parallelize via MCE's forseq method.
##
###############################################################################

## Make an output iterator for gather. Output order is preserved.

sub preserve_order {
   my (%result_n, %result_d); my $order_id = 1;

   return sub {
      my ($chunk_id, $n, $data) = @_;

      $result_n{$chunk_id} = $n;
      $result_d{$chunk_id} = $data;

      while (1) {
         last unless exists $result_d{$order_id};

         printf "n: %s sqrt(n): %f\n",
            $result_n{$order_id}, $result_d{$order_id};

         delete $result_n{$order_id};
         delete $result_d{$order_id};

         $order_id++;
      }

      return;
   };
}

## Configure MCE.

my $seq = {
   begin => $s_begin, end => $s_end, step => $s_step, format => $s_format
};

## use MCE::Flow;    ## Same thing in MCE 1.5+
##
## mce_flow_s {
##    max_workers => 4, chunk_size => 1, gather => preserve_order
## },
## sub {
##    my ($mce, $n, $chunk_id) = @_;
##    MCE->gather($chunk_id, $n, sqrt($n));
##
## }, $s_begin, $s_end, $s_step;

my $mce = MCE->new(
   max_workers => 4, chunk_size => 1, gather => preserve_order
);

## Use $n or $_ to retrieve the single element.

my $start = time;

$mce->forseq( $seq, sub {
   my ($mce, $n, $chunk_id) = @_;
   MCE->gather($chunk_id, $n, sqrt($n));
});

printf {*STDERR} "\n## Compute time: %0.03f\n\n", time - $start;

