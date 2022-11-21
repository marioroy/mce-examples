#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## MCE::Shared's condvar and MCE::Hobo demonstration.
## Also see sync_mce_shared.pl for another use-case.
##
###############################################################################

use strict;
use warnings;

use MCE::Hobo;
use MCE::Shared;
use Time::HiRes qw(sleep);

my $num_workers = 8;
my $cv  = MCE::Shared->condvar;
my $var = MCE::Shared->scalar( 10 );

sub worker {
   my ($id) = @_;
   print("Worker $id [$$]: Begin\n");
   print("Worker $id [$$]: Wait\n"), $cv->wait() until $var->get == 0;
   print("Worker $id [$$]: End\n");
}

my (@procs, $next);

print "Manager  [$$]: Begin\n";
push @procs, MCE::Hobo->new(\&worker, $_) for 1 .. $num_workers;

print "Manager  [$$]: Loop\n";
while ($next = $var->decr) {
   print "$next\n";
   $cv->signal if $next == 5 || $next == 7;
   sleep 0.7;
}

print "Manager  [$$]: Broadcast\n";
$cv->broadcast;

print "Manager  [$$]: Join\n";
$_->join for @procs;

print "Manager  [$$]: End\n";

