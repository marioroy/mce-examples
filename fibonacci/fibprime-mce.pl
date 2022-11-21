#!/usr/bin/env perl

# Based on script fibprime-threads.pl by Dana Jacobsen, 2012.
# Modified to use the core MCE API for parallelization.

use strict;
use warnings;

# Overkill, but let's try to select a good bigint module.
my $bigint_class;
if      (eval { require Math::GMPz; 1; }) {
  $bigint_class = "Math::GMPz";
} elsif (eval { require Math::GMP; 1; }) {
  $bigint_class = "Math::GMP";
} else {
  require Math::BigInt;
  Math::BigInt->import(try=>"GMP,Pari");
  $bigint_class = "Math::BigInt";
}
 
use Math::Prime::Util ':all';
use Time::HiRes qw(gettimeofday tv_interval);

use MCE;
$| = 1;
 
my $time_start = [gettimeofday];
my $nworkers = @ARGV ? shift : 4;
warn "Using $nworkers CPUs\n";

prime_precalc(10_000_000);
 
sub fib_n {
   my ($n, $fibstate) = @_;
   @$fibstate = (1, $bigint_class->new(0), $bigint_class->new(1))
      unless defined $fibstate->[0];
   my ($curn, $a, $b) = @$fibstate;
   die "fib_n only increases" if $n < $curn;
   do { ($a, $b) = ($b, $a+$b); } for (1 .. $n-$curn);
   @$fibstate = ($n, $a, $b);
   $b;
}
 
sub nth_iter {
   my ($n, $tmp) = (0, {});
   return sub {
      if (defined $tmp && keys %$tmp < 25) {
         $tmp->{$_[0]} = $_[1];   ## @_ = ( $nth, [ $k, $time_int ] )
      }
      else {
         if (defined $tmp) {
            $tmp->{$_[0]} = $_[1];
            for my $nth (sort { $a <=> $b } keys %$tmp) {
               my ($k, $time_int) = @{ $tmp->{$nth} };
               printf "%3d %7d %20.5f\n", ++$n, $k, $time_int;
            }
            undef $tmp;
         }
         else {
            printf "%3d %7d %20.5f\n", ++$n, $_[1][0], $_[1][1];
         }
      }
   }
}
 
my $mce = MCE->new(
   max_workers => $nworkers, gather => nth_iter,
   user_func => sub {
      my @fibstate; my $nth = MCE->wid();
      while (1) {
         # Exploit knowledge that excepting k=4, all prime F_k have a prime k.
         my $k = ($nth <= 2) ?  2 + $nth  :  nth_prime($nth);
         my $Fk = fib_n($k, \@fibstate);
         if (is_prob_prime($Fk)) {
            MCE->gather($nth, [ $k, tv_interval($time_start) ]);
         }
         $nth += $nworkers;
      }
   }
)->run;

