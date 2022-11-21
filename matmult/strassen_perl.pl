#!/usr/bin/env perl

# Divide-and-conquer 1 level - pure-Perl implementation (7 workers)
# Usage:
#   perl strassen_perl.pl 1024  # Default matrix size 512

use strict;
use warnings;

my $prog_name = $0;  $prog_name =~ s{^.*[\\/]}{}g;

use Time::HiRes qw(time);
use MCE;

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

my $tam = @ARGV ? shift : 512;

unless (is_power_of_two($tam)) {
   die "error: $tam must be a power of 2 integer.\n";
}

my $mce; $mce = configure_and_spawn_mce() if ($tam > 64);

my $a = [ ];
my $b = [ ];
my $c = [ ];

my $rows = $tam;
my $cols = $tam;
my $cnt;

$cnt = 0; for (0 .. $rows - 1) {
   $a->[$_] = [ $cnt .. $cnt + $cols - 1 ];
   $cnt += $cols;
}

$cnt = 0; for (0 .. $cols - 1) {
   $b->[$_] = [ $cnt .. $cnt + $rows - 1 ];
   $cnt += $rows;
}

my $start = time;
strassen($a, $b, $c, $tam, $mce);
my $end = time;

# Print results -- use same pairs to match David Mertens' output.
printf "\n## $prog_name $tam: compute time: %0.03f secs\n\n", $end - $start;

for my $pair ([0, 0], [324, 5], [42, 172], [$tam-1, $tam-1]) {
   my ($col, $row) = @$pair; $col %= $tam; $row %= $tam;
   printf "## (%d, %d): %s\n", $col, $row, $c->[$row][$col];
}

print "\n";

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

my @p;

sub store_result {

   my ($n, $result) = @_;

   $p[$n] = $result;

   return;
}

sub configure_and_spawn_mce {

   return MCE->new(

      max_workers => 7,

      user_func   => sub {
         my $self = $_[0];
         my $data = $self->{user_data};

         my $tam = $data->[3];
         my $result = [ ];
         strassen_r($data->[0], $data->[1], $result, $tam);

         $self->do('store_result', $data->[2], $result);
      }

   )->spawn;
}

sub is_power_of_two {

   my ($n) = @_;

   return 0 if ($n !~ /^\d+$/); 
   return ($n != 0 && (($n & $n - 1) == 0));
}

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub strassen {

   my ($a, $b, $c, $tam, $mce) = @_;

   if ($tam <= 64) {

      for my $i (0 .. $tam - 1) {
         for my $j (0 .. $tam - 1) {
            $c->[$i][$j] = 0;
            for my $k (0 .. $tam - 1) {
               $c->[$i][$j] += $a->[$i][$k] * $b->[$k][$j];
            }
         }
      }

      return;
   }

   my ($p1, $p2, $p3, $p4, $p5, $p6, $p7);
   my $nTam = $tam / 2;

   my ($a11, $a12, $a21, $a22) = divide_m($a, $nTam);
   my ($b11, $b12, $b21, $b22) = divide_m($b, $nTam);

   my $t1 = [ ];
   my $t2 = [ ];

   sum_m($a11, $a22, $t1, $nTam);
   sum_m($b11, $b22, $t2, $nTam);
   $mce->send([ $t1, $t2, 1, $nTam ]);

   sum_m($a21, $a22, $t1, $nTam);
   $mce->send([ $t1, $b11, 2, $nTam ]);

   subtract_m($b12, $b22, $t2, $nTam);
   $mce->send([ $a11, $t2, 3, $nTam ]);

   subtract_m($b21, $b11, $t2, $nTam);
   $mce->send([ $a22, $t2, 4, $nTam ]);

   sum_m($a11, $a12, $t1, $nTam);
   $mce->send([ $t1, $b22, 5, $nTam ]);

   subtract_m($a21, $a11, $t1, $nTam);
   sum_m($b11, $b12, $t2, $nTam);
   $mce->send([ $t1, $t2, 6, $nTam ]);

   subtract_m($a12, $a22, $t1, $nTam);
   sum_m($b21, $b22, $t2, $nTam);
   $mce->send([ $t1, $t2, 7, $nTam ]);

   $mce->run;

   $p1 = $p[1]; $p2 = $p[2]; $p3 = $p[3]; $p4 = $p[4];
   $p5 = $p[5]; $p6 = $p[6]; $p7 = $p[7];

   calc_m($p1, $p2, $p3, $p4, $p5, $p6, $p7, $c, $nTam);

   return;
}

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub strassen_r {

   my ($a, $b, $c, $tam) = @_;

   # Perform the classic multiplication when matrix is <=  64 X  64

   if ($tam <= 64) {

      for my $i (0 .. $tam - 1) {
         for my $j (0 .. $tam - 1) {
            $c->[$i][$j] = 0;
            for my $k (0 .. $tam - 1) {
               $c->[$i][$j] += $a->[$i][$k] * $b->[$k][$j];
            }
         }
      }

      return;
   }

   # Otherwise, perform multiplication using Strassen's algorithm

   my $nTam = $tam / 2;

   my $t1 = [ ];  my $t2 = [ ];

   my $p1 = [ ];  my $p2 = [ ];
   my $p3 = [ ];  my $p4 = [ ];
   my $p5 = [ ];  my $p6 = [ ];
   my $p7 = [ ];

   # Divide the matrices into 4 sub-matrices

   my ($a11, $a12, $a21, $a22) = divide_m($a, $nTam);
   my ($b11, $b12, $b21, $b22) = divide_m($b, $nTam);

   # Calculate p1 to p7

   sum_m($a11, $a22, $t1, $nTam);
   sum_m($b11, $b22, $t2, $nTam);
   strassen_r($t1, $t2, $p1, $nTam);

   sum_m($a21, $a22, $t1, $nTam);
   strassen_r($t1, $b11, $p2, $nTam);

   subtract_m($b12, $b22, $t2, $nTam);
   strassen_r($a11, $t2, $p3, $nTam);

   subtract_m($b21, $b11, $t2, $nTam);
   strassen_r($a22, $t2, $p4, $nTam);

   sum_m($a11, $a12, $t1, $nTam);
   strassen_r($t1, $b22, $p5, $nTam);

   subtract_m($a21, $a11, $t1, $nTam);
   sum_m($b11, $b12, $t2, $nTam);
   strassen_r($t1, $t2, $p6, $nTam);

   subtract_m($a12, $a22, $t1, $nTam);
   sum_m($b21, $b22, $t2, $nTam);
   strassen_r($t1, $t2, $p7, $nTam);

   # Calculate and group into a single matrix $c

   calc_m($p1, $p2, $p3, $p4, $p5, $p6, $p7, $c, $nTam);

   return;
}

# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #

sub divide_m {

   my ($m, $tam) = @_;

   my $m11 = [ ]; my $m12 = [ ]; my $m21 = [ ]; my $m22 = [ ];

   for my $i (0 .. $tam - 1) {
      for my $j (0 .. $tam - 1) {
         $m11->[$i][$j] = $m->[$i][$j];
         $m12->[$i][$j] = $m->[$i][$j + $tam];
         $m21->[$i][$j] = $m->[$i + $tam][$j];
         $m22->[$i][$j] = $m->[$i + $tam][$j + $tam];
      }
   }

   return ($m11, $m12, $m21, $m22);
}

sub calc_m {

   my ($p1, $p2, $p3, $p4, $p5, $p6, $p7, $c, $tam) = @_;

   my $t1 = [ ];
   my $t2 = [ ];

   sum_m($p1, $p4, $t1, $tam);
   sum_m($t1, $p7, $t2, $tam);
   subtract_m($t2, $p5, $p7, $tam);         # reuse $p7 to store c11

   sum_m($p1, $p3, $t1, $tam);
   sum_m($t1, $p6, $t2, $tam);
   subtract_m($t2, $p2, $p6, $tam);         # reuse $p6 to store c22

   sum_m($p3, $p5, $p1, $tam);              # reuse $p1 to store c12
   sum_m($p2, $p4, $p3, $tam);              # reuse $p3 to store c21

   for my $i (0 .. $tam - 1) {
      for my $j (0 .. $tam - 1) {
         $c->[$i][$j] = $p7->[$i][$j];                   # c11 = $p7
         $c->[$i][$j + $tam] = $p1->[$i][$j];            # c12 = $p1
         $c->[$i + $tam][$j] = $p3->[$i][$j];            # c21 = $p3
         $c->[$i + $tam][$j + $tam] = $p6->[$i][$j];     # c22 = $p6
      }
   }

   return;
}

sub sum_m {

   my ($a, $b, $r, $tam) = @_;

   for my $i (0 .. $tam - 1) {
      for my $j (0 .. $tam - 1) {
         $r->[$i][$j] = $a->[$i][$j] + $b->[$i][$j];
      }
   }

   return;
}

sub subtract_m {

   my ($a, $b, $r, $tam) = @_;

   for my $i (0 .. $tam - 1) {
      for my $j (0 .. $tam - 1) {
         $r->[$i][$j] = $a->[$i][$j] - $b->[$i][$j];
      }
   }

   return;
}

