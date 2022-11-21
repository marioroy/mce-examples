#!/usr/bin/env perl

##
## usage: tbray_baseline1.pl < logfile
##

use strict;
use warnings;

use Time::HiRes qw(time);

my $file = shift;

my $start = time;
open my $IN, '<', $file or die $!;

my $rx = qr|GET /ongoing/When/\d\d\dx/(\d\d\d\d/\d\d/\d\d/[^ .]+) |o;
my %count;
while (<$IN>) {
    next unless $_ =~ $rx;
    $count{$1}++;
}

close $IN;
my $end = time;

print "$count{$_}\t$_\n"
  for ( sort { $count{$b} <=> $count{$a} } keys %count )[ 0 .. 9 ];

printf "\n## Compute time: %0.03f\n\n",  $end - $start;

