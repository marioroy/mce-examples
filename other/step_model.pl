#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## This example demonstrates MCE::Step, MCE->enq, and MCE->gather.
## Allow 5.5 seconds for the ping timeout to expire before seeing results.
##
## This script must be run by root due to constructing Net::Ping->new('syn').
## See also flow_model.pl, using MCE::Flow.
##
###############################################################################

use strict;
use warnings;

use MCE::Step 1.818;
use Net::Ping;

###############################################################################

## Configure MCE options.
## The user_begin and user_end callbacks are called by each worker process.
## Unlike the flow_model.pl example, task_end is ignored if specified here.

MCE::Step::init {

   interval => 0.030,

   user_begin => sub {
      my ($mce) = @_;

      if (MCE->task_name eq 'pinger') {
         $mce->{pinger} = Net::Ping->new('syn');
         $mce->{pinger}->hires;
      }

      return;
   },

   user_end => sub {
      my ($mce) = @_;

      if (MCE->task_name eq 'pinger') {
         $mce->{pinger}->close;
      }

      return;
   }

};

###############################################################################

## There are 2 sub-tasks below. Pinger calls gather for failed pings. However,
## task2 calls gather twice. Think of gather as yielding data which may be
## called as often as needed.

sub pinger {

   my ($mce, $chunk_ref, $chunk_id) = @_;

   my $pinger = $mce->{pinger};
   my %pass   = ();
   my @fail   = ();

   # Delay momentarily to prevent many workers initiating pings to many hosts
   # simultaneously. The interval option is described in MCE::Core.pod.

   MCE->yield();

   # $chunk_ref points to an array containing chunk_size items.

   foreach my $host ( @{ $chunk_ref } ) {
      $pinger->ping($host, 3.333);
   }

   # Let pinger process entire chunk all at once.

   while ((my $host, my $rtt, my $ip) = $pinger->ack) {
      $pass{$host} = $pass{$ip} = 1;
   }

   # Process hosts/IPs.

   my @successful;

   foreach my $host ( @{ $chunk_ref } ) {
      unless (exists $pass{$host}) {
         MCE->gather("$host.status", "Failed ping");
      } else {
         push @successful, $host;
      }
   }

   # Enqueue all at once for successful hosts/IPs.

   MCE->enq('task2', \@successful) if (@successful);

   return;
}

sub task2 {

   my ($mce, $successful_hosts) = @_;

   foreach my $host ( @{ $successful_hosts } ) {

      # do something with $host if desired
      my %h = ();

      $h{raw} = "test result";
      $h{fun} = "other data";

      # gather key-value pairs for %r = mce_step { ... }
      MCE->gather("$host.status", "Successful");
      MCE->gather("$host.data", \%h);
   }

   return;
}

###############################################################################

## Two of the IPs will fail. This can very well be a large array.
## The pinger workers will process an entire chunk all at once.

my @h = qw( 127.0.0.1  127.0.0.8  127.0.0.9 );

## MCE options can be passed here or through MCE::Step::init above.
## Both max_workers and task_name options support an array reference
## for setting each sub-task individually. The two gather calls in
## task2 above send key/value pair(s) to the manager-process and
## returned into the hash variable %r.

print "## Please wait. This can take 3.4 seconds.\n";

my %r = mce_step {
   chunk_size  => 50,
   max_workers => [ 8, 4 ],
   task_name   => [ 'pinger', 'task2' ]
}, \&pinger, \&task2, @h;

## Output
##   127.0.0.1: Successful: test result
##   127.0.0.8: Failed ping: 
##   127.0.0.9: Failed ping: 

foreach my $host (@h) {
   my $status  = $r{"$host.status"};
   my $rawdata = (exists $r{"$host.data"}) ? $r{"$host.data"}->{raw} : "";
   print "$host: $status: $rawdata\n";
}

