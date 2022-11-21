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
## usage: forchunk.pl [ size ]
##
###############################################################################

use strict;
use warnings;

use Time::HiRes qw(time);
use MCE;

my $prog_name = $0; $prog_name =~ s{^.*[\\/]}{}g;
my $size = shift || 3000;

unless ($size =~ /\A\d+\z/) {
   print {*STDERR} "usage: $prog_name [ size ]\n";
   exit;
}

my @input_data = (0 .. $size - 1);

###############################################################################
## ----------------------------------------------------------------------------
## Parallelize via MCE's foreach method.
##
###############################################################################

## Make an output iterator for gather. Output order is preserved.

my $chunk_size = 2500;

sub preserve_order {
   my %tmp; my $order_id = 1;

   return sub {
      my ($chunk_id, $data_ref) = @_;
      $tmp{$chunk_id} = $data_ref;

      while (1) {
         last unless exists $tmp{$order_id};
         my $i = ($order_id - 1) * $chunk_size;

         for ( @{ $tmp{$order_id} } ) {
            printf "n: %d sqrt(n): %f\n", $input_data[$i++], $_;
         }

         delete $tmp{$order_id++};
      }

      return;
   };
}

## Configure MCE.

## use MCE::Flow;    ## Same thing in MCE 1.5+
##
## mce_flow {
##    max_workers => 4, chunk_size => $chunk_size,
##    gather => preserve_order
## },
## sub {
##    my ($mce, $chunk_ref, $chunk_id) = @_;
##    my @result;
## 
##    for ( @{ $chunk_ref } ) {
##       push @result, sqrt($_);
##    }
## 
##    MCE->gather($chunk_id, \@result);
## 
## }, @input_data;

my $mce = MCE->new(
   max_workers => 4, chunk_size => $chunk_size,
   gather => preserve_order
);

## Below, $chunk_ref is a reference to an array containing the next
## $chunk_size items from @input_data.

my $start = time;

$mce->forchunk( \@input_data, sub {
   my ($mce, $chunk_ref, $chunk_id) = @_;
   my @result;

   for ( @{ $chunk_ref } ) {
      push @result, sqrt($_);
   }

   MCE->gather($chunk_id, \@result);
});

printf {*STDERR} "\n## Compute time: %0.03f\n\n", time - $start;

