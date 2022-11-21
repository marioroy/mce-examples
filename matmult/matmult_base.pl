#!/usr/bin/env perl

# Usage:
#   perl matmult_base.pl 1024                # Default matrix size 512
#   perl matmult_base.pl 1024 [ N_threads ]  # Requires PDL::LinearAlgebra::Real

use strict;
use warnings;

my $prog_name = $0;  $prog_name =~ s{^.*[\\/]}{}g;

use PDL;
use Time::HiRes qw(time);

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

my $tam = @ARGV ? shift : 512;

if ($tam !~ /^\d+$/ || $tam < 2) {
   die "error: $tam must be an integer greater than 1.\n";
}

# Compute faster with LAPACK/OpenBLAS.
if (@ARGV) {
   local $@; $ENV{'OMP_NUM_THREADS'} = shift;
   eval q{ PDL::set_autopthread_targ(1) };
   eval q{ use PDL::LinearAlgebra::Real };
}

my ($cols, $rows) = ($tam, $tam);

my $a = sequence(double, $cols, $rows);
my $b = sequence(double, $rows, $cols);

my $start = time;
my $c = $a x $b;                         # Performs matrix multiplication
my $end = time;

# Print results -- use same pairs to match David Mertens' output.
printf "\n## $prog_name $tam: compute time: %0.03f secs\n\n", $end - $start;

for my $pair ([0, 0], [324, 5], [42, 172], [$rows-1, $rows-1]) {
   my ($col, $row) = @$pair; $col %= $rows; $row %= $rows;
   printf "## (%d, %d): %s\n", $col, $row, $c->at($col, $row);
}

print "\n";

