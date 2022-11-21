#!/usr/bin/env perl
 
# This script was taken from https://gist.github.com/run4flat/4942132 for
# folks wanting to review, study, and compare with MCE. Script was modified
# to support the optional N_threads argument.
#
# Usage:
#   perl matmult_simd.pl 1024 [ N_threads   ]  # Default matrix size 512
#   perl matmult_simd.pl 1024 [ N_threads 1 ]  # Use PDL::LinearAlgebra::Real
#                                              #  if available
#
# by David Mertens
# based on code by Mario Roy
 
#################
# Preliminaries #
#################

use strict;
use warnings;

my $prog_name = $0;  $prog_name =~ s{^.*[\\/]}{}g;
 
use PDL;
use PDL::Parallel::threads qw(retrieve_pdls);
use PDL::Parallel::threads::SIMD qw(parallel_id parallelize);
use Time::HiRes qw(time);

# PDL data should not be naively copied in new threads.
# Suppress PDL warnings; automatic since PDL::Parallel::threads 0.04.
{
    no warnings;
    sub PDL::CLONE_SKIP { 1 }
}

###########################
# Create some shared data #
###########################
 
# Get the matrix size and croak on bad input
my $tam = @ARGV ? shift : 512;
my $N_threads = @ARGV ? shift : 4;

if ($tam !~ /^\d+$/ or $tam < 2) {
    die "error: $tam must be an integer greater than 1.\n";
}
 
# Disable multithreading in PDL 2.059+.
# Compute faster with LAPACK/OpenBLAS.
{
    local $@; $ENV{'OMP_NUM_THREADS'} = 1;
    eval q{ PDL::set_autopthread_targ(1) };
    eval q{ use PDL::LinearAlgebra::Real } if shift;
}

my $cols = $tam;
my $rows = $tam;
 
sequence(double, $cols, $rows)->share_as('left_input');
sequence(double, $rows, $cols)->share_as('right_input');
my $output = zeroes(double, $rows, $rows)->share_as('output');
 
###################################
# Run the calculation in parallel #
###################################
 
my $start = time;

parallelize {
    my ($l, $r, $o) = retrieve_pdls('left_input', 'right_input', 'output');
    my $pid = parallel_id;
	
    # chop up the input matrix based on the number of rows
    # and the number of threads.
    my $step = int(($rows + $N_threads - 1) / $N_threads);
    my $start = $pid * $step;
    my $stop = $start + $step - 1;

    $stop = $rows - 1 if $stop >= $rows;
    return if $start > $stop;

    use PDL::NiceSlice;
    $o(:, $start:$stop) .= $l(:,$start:$stop) x $r;
    no PDL::NiceSlice;
} $N_threads;

my $end = time;
 
#################
# Print results #
#################
 
printf "\n## $prog_name $tam: compute time: %0.03f secs\n\n", $end - $start;
 
for my $pair ([0, 0], [324, 5], [42, 172], [$tam-1, $tam-1]) {
    my ($row, $col) = @$pair;
    $row %= $rows;
    $col %= $cols;
    print "## ($row, $col): ", $output->at($row, $col), "\n";
}

print "\n";

