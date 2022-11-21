#!/usr/bin/env perl

# Usage:
#   perl matmult_mce_t.pl 1024 [ N_threads   ]  # Default matrix size 512
#   perl matmult_mce_t.pl 1024 [ N_threads 1 ]  # Use PDL::LinearAlgebra::Real
#                                               #  if available

use strict;
use warnings;

my $prog_name = $0;  $prog_name =~ s{^.*[\\/]}{}g;

use threads;
use PDL;
use PDL::Parallel::threads qw(retrieve_pdls);
use Time::HiRes qw(time);

use MCE;

# PDL data should not be naively copied in new threads.
# Suppress PDL warnings; automatic since MCE 1.877.
{
   no warnings;
   sub PDL::CLONE_SKIP { 1 }
}

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

my $tam = @ARGV ? shift : 512;
my $N_threads = @ARGV ? shift : 4;

if ($tam !~ /^\d+$/ || $tam < 2) {
   die "error: $tam must be an integer greater than 1.\n";
}

# Disable multithreading in PDL 2.059+.
# Compute faster with LAPACK/OpenBLAS.
{
   local $@; $ENV{'OMP_NUM_THREADS'} = 1;
   eval q{ PDL::set_autopthread_targ(1) };
   eval q{ use PDL::LinearAlgebra::Real } if shift;
}

my ($cols, $rows) = ($tam, $tam);
my $step_size = $INC{'PDL/LinearAlgebra/Real.pm'} ? 128 : 8;
my $mce = configure_and_spawn_mce($N_threads);

sequence(double, $cols, $rows)->share_as('left_input');
sequence(double, $rows, $cols)->share_as('right_input');
sequence(double, $rows, $rows)->share_as('output');

my $start = time;
$mce->run(0, { sequence => [ 0, $rows - 1, $step_size ] });
my $end = time;

$mce->shutdown;

# Print results -- use same pairs to match David Mertens' output.
printf "\n## $prog_name $tam: compute time: %0.03f secs\n\n", $end - $start;

my ($output) = retrieve_pdls('output');

for my $pair ([0, 0], [324, 5], [42, 172], [$rows-1, $rows-1]) {
   my ($col, $row) = @$pair; $col %= $rows; $row %= $rows;
   printf "## (%d, %d): %s\n", $col, $row, $output->at($col, $row);
}

print "\n";

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub configure_and_spawn_mce {

   my $N_threads = shift;

   return MCE->new(

      max_workers => $N_threads,

      user_begin  => sub {
         my ($self) = @_;
         ($self->{l}, $self->{r}, $self->{o}) = retrieve_pdls(
            'left_input', 'right_input', 'output'
         );
      },

      user_func   => sub {
         my ($self, $seq_n, $chunk_id) = @_;

         my $start = $seq_n;
         my $stop  = $start + $step_size - 1;
         $stop = $rows - 1 if ($stop >= $rows);

         my $l = $self->{l};
         my $r = $self->{r};
         my $o = $self->{o};

         use PDL::NiceSlice;
         $o(:,$start:$stop) .= $l(:,$start:$stop) x $r;
         no PDL::NiceSlice;

         return;
      }

   )->spawn;
}

