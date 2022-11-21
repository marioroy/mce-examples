#!/usr/bin/env perl

# Divide-and-conquer 2 levels - using PDL (49 workers)
# Usage:
#   perl strassen_49_t.pl 1024     # Default matrix size 512
#   perl strassen_49_t.pl 1024 1   # Use PDL::LinearAlgebra::Real
#                                  #  if available

use strict;
use warnings;

my $prog_name = $0;  $prog_name =~ s{^.*[\\/]}{}g;

use threads;
use PDL;
use PDL::Parallel::threads qw(retrieve_pdls free_pdls);
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

unless (is_power_of_two($tam)) {
   die "error: $tam must be a power of 2 integer.\n";
}

# Disable multithreading in PDL 2.059+.
# Compute faster with LAPACK/OpenBLAS.
{
   local $@; $ENV{'OMP_NUM_THREADS'} = 1;
   eval q{ PDL::set_autopthread_targ(1) };
   eval q{ use PDL::LinearAlgebra::Real } if shift;
}

my $mce; $mce = configure_and_spawn_mce() if ($tam > 128);

my $a = sequence(double, $tam, $tam);
my $b = sequence(double, $tam, $tam);
my $c =   zeroes(double, $tam, $tam);

my $start = time;
strassen($a, $b, $c, $tam, $mce);
my $end = time;

$mce->shutdown if (defined $mce);

# Print results -- use same pairs to match David Mertens' output.
printf "\n## $prog_name $tam: compute time: %0.03f secs\n\n", $end - $start;

for my $pair ([0, 0], [324, 5], [42, 172], [$tam-1, $tam-1]) {
   my ($col, $row) = @$pair; $col %= $tam; $row %= $tam;
   printf "## (%d, %d): %s\n", $col, $row, $c->at($col, $row);
}

print "\n";

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub configure_and_spawn_mce {

   return MCE->new(

      max_workers => 49,

      user_func   => sub {
         my $self = $_[0];
         my $data = $self->{user_data};

         my $sess_dir = $self->sess_dir;

         my $tam = $data->[1];
         my $result = zeroes $tam,$tam;

         my ($a, $b) = retrieve_pdls(
            "$sess_dir/". $data->[0] ."a",
            "$sess_dir/". $data->[0] ."b"
         );

         strassen_r($a, $b, $result, $tam);

         free_pdls($a, $b);

         $result->share_as("$sess_dir/p" . $data->[0]);
      }

   )->spawn;
}

sub is_power_of_two {

   my ($n) = @_;

   return 0 if ($n !~ /^\d+$/); 
   return ($n != 0 && (($n & $n - 1) == 0));
}

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub submit {

   my ($a, $b, $c, $tam, $mce, $t1, $t2) = @_;

   my $sess_dir = $mce->sess_dir;
   my $nTam = $tam / 2;

   my ($a11, $a12, $a21, $a22) = divide_m($a, $nTam);
   my ($b11, $b12, $b21, $b22) = divide_m($b, $nTam);

   sum_m($a11, $a22, $t1, $nTam);
   sum_m($b11, $b22, $t2, $nTam);
   $t1->copy->sever->share_as( "$sess_dir/". ($c + 1) ."a");
   $t2->copy->sever->share_as( "$sess_dir/". ($c + 1) ."b");
   $mce->send([ $c + 1, $nTam ]);

   sum_m($a21, $a22, $t1, $nTam);
   $t1->copy->sever->share_as( "$sess_dir/". ($c + 2) ."a");
   $b11->copy->sever->share_as("$sess_dir/". ($c + 2) ."b");
   $mce->send([ $c + 2, $nTam ]);

   subtract_m($b12, $b22, $t2, $nTam);
   $a11->copy->sever->share_as("$sess_dir/". ($c + 3) ."a");
   $t2->copy->sever->share_as( "$sess_dir/". ($c + 3) ."b");
   $mce->send([ $c + 3, $nTam ]);

   subtract_m($b21, $b11, $t2, $nTam);
   $a22->copy->sever->share_as("$sess_dir/". ($c + 4) ."a");
   $t2->copy->sever->share_as( "$sess_dir/". ($c + 4) ."b");
   $mce->send([ $c + 4, $nTam ]);

   sum_m($a11, $a12, $t1, $nTam);
   $t1->copy->sever->share_as( "$sess_dir/". ($c + 5) ."a");
   $b22->copy->sever->share_as("$sess_dir/". ($c + 5) ."b");
   $mce->send([ $c + 5, $nTam ]);

   subtract_m($a21, $a11, $t1, $nTam);
   sum_m($b11, $b12, $t2, $nTam);
   $t1->copy->sever->share_as( "$sess_dir/". ($c + 6) ."a");
   $t2->copy->sever->share_as( "$sess_dir/". ($c + 6) ."b");
   $mce->send([ $c + 6, $nTam ]);

   subtract_m($a12, $a22, $t1, $nTam);
   sum_m($b21, $b22, $t2, $nTam);

   unless ($c == 10) {
      $t1->copy->sever->share_as( "$sess_dir/". ($c + 7) ."a");
      $t2->copy->sever->share_as( "$sess_dir/". ($c + 7) ."b");
   }
   else {
      $t1->share_as( "$sess_dir/". ($c + 7) ."a");
      $t2->share_as( "$sess_dir/". ($c + 7) ."b");
   }

   $mce->send([ $c + 7, $nTam ]);

   return;
}

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub strassen {

   my ($a, $b, $c, $tam, $mce) = @_;

   if ($tam <= 128) {
      ins(inplace($c), $a x $b);
      return;
   }

   my $sess_dir = $mce->sess_dir;

   my (@p, $p1, $p2, $p3, $p4, $p5, $p6, $p7);
   my $nTam = $tam / 2;

   my ($a11, $a12, $a21, $a22) = divide_m($a, $nTam);
   my ($b11, $b12, $b21, $b22) = divide_m($b, $nTam);

   my $t1 = zeroes $nTam,$nTam;
   my $u1 = zeroes $nTam/2,$nTam/2;
   my $u2 = zeroes $nTam/2,$nTam/2;

   sum_m($a21, $a22, $t1, $nTam);
   submit($t1, $b11, 20, $nTam, $mce, $u1, $u2);

   subtract_m($b12, $b22, $t1, $nTam);
   submit($a11, $t1, 30, $nTam, $mce, $u1, $u2);

   subtract_m($b21, $b11, $t1, $nTam);
   submit($a22, $t1, 40, $nTam, $mce, $u1, $u2);

   sum_m($a11, $a12, $t1, $nTam);
   submit($t1, $b22, 50, $nTam, $mce, $u1, $u2);

   subtract_m($a12, $a22, $t1, $nTam);
   sum_m($b21, $b22, $a12, $nTam);               # Reuse $a12
   submit($t1, $a12, 70, $nTam, $mce, $u1, $u2);

   subtract_m($a21, $a11, $t1, $nTam);
   sum_m($b11, $b12, $a12, $nTam);               # Reuse $a12
   submit($t1, $a12, 60, $nTam, $mce, $u1, $u2);

   sum_m($a11, $a22, $t1, $nTam);
   sum_m($b11, $b22, $a12, $nTam);               # Reuse $a12
   submit($t1, $a12, 10, $nTam, $mce, $u1, $u2);

   $mce->run(0);

   for my $i (1 .. 7) {
      $p[$i] = zeroes $nTam,$nTam;

      ($p1, $p2, $p3, $p4, $p5, $p6, $p7) = retrieve_pdls(
         "$sess_dir/p$i"."1", "$sess_dir/p$i"."2", "$sess_dir/p$i"."3",
         "$sess_dir/p$i"."4", "$sess_dir/p$i"."5", "$sess_dir/p$i"."6",
         "$sess_dir/p$i"."7"
      );

      calc_m($p1, $p2, $p3, $p4, $p5, $p6, $p7, $p[$i], $nTam/2, $u1,$u2);

      free_pdls($p1, $p2, $p3, $p4, $p5, $p6, $p7);
   }

   calc_m($p[1],$p[2],$p[3],$p[4],$p[5],$p[6],$p[7], $c, $nTam, $t1, $a12);

   return;
}

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub strassen_r {

   my ($a, $b, $c, $tam) = @_;

   # Perform the classic multiplication when matrix is <= 128 X 128

   if ($tam <= 128) {
      ins(inplace($c), $a x $b);
      return;
   }

   # Otherwise, perform multiplication using Strassen's algorithm

   my $nTam = $tam / 2;

   my $p2 = zeroes $nTam,$nTam; my $p3 = zeroes $nTam,$nTam;
   my $p4 = zeroes $nTam,$nTam; my $p5 = zeroes $nTam,$nTam;

   # Divide the matrices into 4 sub-matrices

   my ($a11, $a12, $a21, $a22) = divide_m($a, $nTam);
   my ($b11, $b12, $b21, $b22) = divide_m($b, $nTam);

   # Calculate p1 to p7

   my $t1 = zeroes $nTam,$nTam;

   sum_m($a21, $a22, $t1, $nTam);
   strassen_r($t1, $b11, $p2, $nTam);

   subtract_m($b12, $b22, $t1, $nTam);
   strassen_r($a11, $t1, $p3, $nTam);

   subtract_m($b21, $b11, $t1, $nTam);
   strassen_r($a22, $t1, $p4, $nTam);

   sum_m($a11, $a12, $t1, $nTam);
   strassen_r($t1, $b22, $p5, $nTam);

   subtract_m($p4, $p5, $t1, $nTam);             # c11
   ins(inplace($c), $t1, 0, 0);

   sum_m($p3, $p5, $t1, $nTam);                  # c12
   ins(inplace($c), $t1, $nTam, 0);

   sum_m($p2, $p4, $t1, $nTam);                  # c21
   ins(inplace($c), $t1, 0, $nTam);

   subtract_m($p3, $p2, $t1, $nTam);             # c22
   ins(inplace($c), $t1, $nTam, $nTam);

   my $t2 = zeroes $nTam,$nTam;

   sum_m($a11, $a22, $t1, $nTam);
   sum_m($b11, $b22, $t2, $nTam);
   strassen_r($t1, $t2, $p2, $nTam);             # Reuse $p2 to store p1

   subtract_m($a21, $a11, $t1, $nTam);
   sum_m($b11, $b12, $t2, $nTam);
   strassen_r($t1, $t2, $p3, $nTam);             # Reuse $p3 to store p6

   subtract_m($a12, $a22, $t1, $nTam);
   sum_m($b21, $b22, $t2, $nTam);
   strassen_r($t1, $t2, $p4, $nTam);             # Reuse $p4 to store p7

   my $n1 = $nTam - 1;
   my $n2 = $nTam + $n1;

   sum_m($p2, $p4, $t1, $nTam);                  # c11
   use PDL::NiceSlice;
   $c(0:$n1,0:$n1) += $t1;
   no PDL::NiceSlice;

   sum_m($p2, $p3, $t1, $nTam);                  # c22
   use PDL::NiceSlice;
   $c($nTam:$n2,$nTam:$n2) += $t1;
   no PDL::NiceSlice;

   return;
}

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub divide_m {

   my ($m, $tam) = @_;

   my $n1 = $tam - 1;
   my $n2 = $tam + $n1;

   return (
      $m->slice("0:$n1,0:$n1")->sever(),        # m11
      $m->slice("$tam:$n2,0:$n1")->sever(),     # m12
      $m->slice("0:$n1,$tam:$n2")->sever(),     # m21
      $m->slice("$tam:$n2,$tam:$n2")->sever()   # m22
   );
}

sub calc_m {

   my ($p1, $p2, $p3, $p4, $p5, $p6, $p7, $c, $tam, $t1, $t2) = @_;

   sum_m($p1, $p4, $t1, $tam);
   sum_m($t1, $p7, $t2, $tam);
   subtract_m($t2, $p5, $p7, $tam);         # reuse $p7 to store c11

   sum_m($p1, $p3, $t1, $tam);
   sum_m($t1, $p6, $t2, $tam);
   subtract_m($t2, $p2, $p6, $tam);         # reuse $p6 to store c22

   sum_m($p3, $p5, $p1, $tam);              # reuse $p1 to store c12
   sum_m($p2, $p4, $p3, $tam);              # reuse $p3 to store c21

   ins(inplace($c), $p7, 0, 0);             # c11 = $p7
   ins(inplace($c), $p1, $tam, 0);          # c12 = $p1
   ins(inplace($c), $p3, 0, $tam);          # c21 = $p3
   ins(inplace($c), $p6, $tam, $tam);       # c22 = $p6

   return;
}

sub sum_m {

   my ($a, $b, $r, $tam) = @_;

   ins(inplace($r), $a + $b);

   return;
}

sub subtract_m {

   my ($a, $b, $r, $tam) = @_;

   ins(inplace($r), $a - $b);

   return;
}

