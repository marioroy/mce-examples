#!/usr/bin/env perl

# Usage:
#   perl matmult_mce_d.pl 1024 [ N_threads   ]  # Default matrix size 512
#   perl matmult_mce_d.pl 1024 [ N_threads 1 ]  # Use PDL::LinearAlgebra::Real
#                                               #  if available

use strict;
use warnings;

my $prog_name = $0;  $prog_name =~ s{^.*[\\/]}{}g;

use PDL;
use PDL::IO::FastRaw;
use Time::HiRes qw(time);

use MCE::Signal qw($tmp_dir -use_dev_shm);
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

my $left_input = sequence(double, $cols, $rows);
writefraw(sequence(double, $rows, $cols), "$tmp_dir/right_input");
my $output = zeroes(double, $rows, $rows);

my $start = time;
$mce->run(0, { sequence => [ 0, $rows - 1, $step_size ] });
my $end = time;

$mce->shutdown;

# Print results -- use same pairs to match David Mertens' output.
printf "\n## $prog_name $tam: compute time: %0.03f secs\n\n", $end - $start;

for my $pair ([0, 0], [324, 5], [42, 172], [$rows-1, $rows-1]) {
   my ($col, $row) = @$pair; $col %= $rows; $row %= $rows;
   printf "## (%d, %d): %s\n", $col, $row, $output->at($col, $row);
}

print "\n";

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub get_rows {

   my ($start) = @_;
   my $stop = $start + $step_size - 1;
   $stop = $rows - 1 if ($stop >= $rows);

   return $left_input->slice(":,$start:$stop")->sever();
}

sub insert_rows {

   my ($seq_n, $result_chunk) = @_;

   ins(inplace($output), $result_chunk, 0, $seq_n);

   return;
}

sub configure_and_spawn_mce {

   my $N_threads = shift;

   return MCE->new(

      max_workers => $N_threads,

      user_begin  => sub {
         my ($self) = @_;
         $self->{r} = mapfraw("$tmp_dir/right_input", { ReadOnly => 1 });
      },

      user_func   => sub {
         my ($self, $seq_n, $chunk_id) = @_;

         my $l_chunk = $self->do('get_rows', $seq_n);
         $self->do('insert_rows', $seq_n, $l_chunk x $self->{r});

         return;
      }

   )->spawn;
}

