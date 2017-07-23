#!/usr/bin/env perl
 
##
## This script was taken from https://gist.github.com/run4flat/4942132 for
## folks wanting to review, study, and compare with MCE. Script was modified
## to support the optional N_threads argument.
##
## Usage:
##    perl matmult_simd.pl 1024 [ N_threads ]      ## Default matrix size 512
##                                                 ## Default N_threads 4
##
## by David Mertens
## based on code by Mario Roy
##
 
#################
# Preliminaries #
#################
 
use strict;
use warnings;

my $prog_name = $0; $prog_name =~ s{^.*[\\/]}{}g;
 
use Time::HiRes qw(time);
 
use PDL;
use PDL::Parallel::threads qw(retrieve_pdls);
use PDL::Parallel::threads::SIMD qw(parallel_id parallelize);

PDL::no_clone_skip_warning if PDL->can('no_clone_skip_warning');

# Get the matrix size and croak on bad input
my $tam = @ARGV ? shift : 512;
die "error: $tam must be an integer greater than 1.\n"
  if $tam !~ /^\d+$/ or $tam < 2;
 
my $cols = $tam;
my $rows = $tam;
 
###########################
# Create some shared data #
###########################
 
sequence($cols, $rows)->share_as('left_input');
sequence($rows, $cols)->share_as('right_input');
my $output = zeroes($rows, $rows)->share_as('output');
my $N_threads = @ARGV ? shift : 4;
 
###################################
# Run the calculation in parallel #
###################################
 
my $start = time;
parallelize {
	my ($l, $r, $o) = retrieve_pdls('left_input', 'right_input', 'output');
	my $pid = parallel_id;
	
	# chop up the input matrix based on the number of rows and the number
	# of threads.
	my $step = int($rows / $N_threads + 0.99);
	my $start = $pid * $step;
	my $stop = ($pid + 1) * $step - 1;
	$stop = $rows - 1 if $stop >= $rows;
	
 	use PDL::NiceSlice;
 	$o(:, $start:$stop) .= $l(:,$start:$stop) x $r;
 	no PDL::NiceSlice;
} $N_threads;
my $end = time;
 
#########################
# Print results #
#########################
 
printf "\n## $prog_name $tam: compute time: %0.03f secs\n\n", $end - $start;
 
for my $pair ([0, 0], [324, 5], [42, 172], [$tam-1, $tam-1]) {
	my ($row, $col) = @$pair;
	$row %= $rows;
	$col %= $cols;
	print "## ($row, $col): ", $output->at($row, $col), "\n";
}

print "\n";

