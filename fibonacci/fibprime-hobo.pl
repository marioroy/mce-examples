#!/usr/bin/env perl

# Based on script fibprime-threads.pl by Dana Jacobsen, 2012.
# Modified to use MCE::Hobo/MCE::Shared for parallelization.

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

use MCE::Hobo;
use MCE::Shared;
$| = 1;
 
my $time_start = [gettimeofday];
my $nthreads = @ARGV ? shift : 4;
warn "Using $nthreads CPUs\n";

prime_precalc(10_000_000);

my $cv    = MCE::Shared->condvar();  # condition/mutex variable
my $found = MCE::Shared->hash();     # add primes found here
my @threads;

push @threads, MCE::Hobo->create('fibprime', $_) for 1 .. $nthreads;
 
# Let the threads work for a little before starting the display loop
my $n = 0; my $delay_output = 1;
sleep 2;

while (1) {
   $cv->wait(); # Someone has found a result.
   $cv->lock();
   if ($delay_output) {
      $cv->unlock(), next if ($found->len < 26);
      $delay_output = 0;
   }
   my $copy = $found->flush();  # pair(s) ( $nth, $k." ".$time_int )
   $cv->unlock();
   foreach ( sort { $a <=> $b } $copy->keys ) {
      printf "%3d %7d %20.5f\n", ++$n, split(/ /, $copy->get($_));
   }
}

$_->join() for (@threads);
 
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
 
sub fibprime {
   my $tnum = shift;
   my @fibstate; my $nth = $tnum;
   while (1) {
      # Exploit knowledge that excepting k=4, all prime F_k have a prime k.
      my $k  = ($nth <= 2) ?  2 + $nth : nth_prime($nth);
      my $Fk = fib_n($k, \@fibstate);
      if (is_prob_prime($Fk)) {
         $cv->lock();
         $found->set($nth, $k . " " . tv_interval($time_start));
         $cv->signal();
      }
      $nth += $nthreads;
   }
}

