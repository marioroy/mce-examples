#!/usr/bin/env perl

use strict;
use warnings;

use MCE::Flow   1.818;
use MCE::Shared 1.814;

# Results from CentOS 7 VM (4 cores): time flow_demo.pl | wc -l
#
# fast 0:  1.765s
# fast 1:  1.361s  # With fast optimization

my $setter_q = MCE::Shared->queue( fast => 1, await => 1 );
my $pinger_q = MCE::Shared->queue( fast => 1, await => 1 );
my $writer_q = MCE::Shared->queue( fast => 1, await => 1 );

# Start the Shared server ( may be ommitted if Perl has IO::FDPass ).

MCE::Shared::start();

# See https://metacpan.org/pod/MCE::Core#SYNTAX-for-INPUT_DATA for a DBI
# input iterator (db_iter). Set chunk_size accordingly. Do not go above
# 300 for chunk_size if running a SNMP crawling (imho).

sub make_number_iter {
   my ($first, $last) = @_;
   my $done; my $n = $first;

   return sub {
      my $chunk_size = $_[0]; return if $done;

      my $min = ($n + $chunk_size - 1 > $last) ? $last : $n + $chunk_size - 1;
      my @numbers = ($n .. $min);

      $n = $min + 1; $done = 1 if $min == $last;

      return @numbers;
   };
}

# Begin and End functions.

sub _begin {
   my ($mce, $task_id, $task_name) = @_;

   if ($task_name eq 'writer') {
    # $mce->{dbh} = DBI->connect(...);
      $mce->{dbh} = 'each (writer) obtains db handle once';
   }

   return;
}

sub _end {
   my ($mce, $task_id, $task_name) = @_;

   if ($task_name eq 'writer') {
    # $mce->{dbh}->disconnect;
      delete $mce->{dbh};
   }

   return;
}

# Actual roles. Uncomment MCE->yield below if processing thousands or more.

sub poller {
   my ($mce, $chunk_ref, $chunk_id) = @_;
   my (@pinger_w, @setter_w, @writer_w);
 # MCE->yield;                    # run gracefully, see examples/interval.pl

   foreach (@$chunk_ref) {
      if ($_ % 100 == 0) {
         push @pinger_w, $_;      # poller cannot connect, check ping status
      }
      else {
         if ($_ % 33 == 0) {
            push @setter_w, $_;   # device needs settings
         }
         else {
            push @writer_w, $_;   # all is well
         }
      }
   }

   if ( @pinger_w ) {
      $pinger_q->await(120); # wait until pinger has 120 or below items
      $pinger_q->enqueue( [ \@pinger_w, $chunk_id, 'ping' ] );
   }
   if ( @setter_w ) {
      $setter_q->await(120); # ditto for the setter queue
      $setter_q->enqueue( [ \@setter_w, $chunk_id, 'set ' ] );
   }
   if ( @writer_w ) {
      $writer_q->await(120); # ditto for the writer queue
      $writer_q->enqueue( [ \@writer_w, $chunk_id, 'ok  ' ] );
   }

   return;
}

sub setter {
   my ($mce) = @_;
 # MCE->yield;                    # adjust interval option below; 0.008

   while (defined (my $next_ref = $setter_q->dequeue)) {
      my ($chunk_ref, $chunk_id, $status) = @{ $next_ref };
      $writer_q->enqueue( [ $chunk_ref, $chunk_id, $status ] );
   }

   return;
}

sub pinger {
   my ($mce) = @_;
 # MCE->yield;                    # all workers are assigned an interval slot

   while (defined (my $next_ref = $pinger_q->dequeue)) {
      my ($chunk_ref, $chunk_id, $status) = @{ $next_ref };
      $writer_q->enqueue( [ $chunk_ref, $chunk_id, $status ] );
   }

   return;
}

sub writer {
   my ($mce) = @_;
   my $dbh = $mce->{dbh};

   while (defined (my $next_ref = $writer_q->dequeue)) {
      my ($chunk_ref, $chunk_id, $status) = @{ $next_ref };
      MCE->say("$chunk_id $status " . scalar @$chunk_ref);
   }

   return;
}

# Configure MCE options; task_name, max_workers can take and anonymous array.
#
# Change max_workers to [ 160, 100, 80, 4 ] if processing millions of rows.
# Also tune netfilter on Linux: /etc/sysctl.conf
# net.netfilter.nf_conntrack_udp_timeout = 10
# net.netfilter.nf_conntrack_udp_timeout_stream = 10
# net.nf_conntrack_max = 131072

my $n_pollers = 100;
my $n_setters =  20;
my $n_pingers =  10;
my $n_writers =   4;

MCE::Flow::init {
   chunk_size => 300, input_data => make_number_iter(1, 2_000_000),
   interval => 0.008, user_begin => \&_begin, user_end => \&_end,

   task_name   => [ 'poller',   'setter',   'pinger',   'writer'   ],
   max_workers => [ $n_pollers, $n_setters, $n_pingers, $n_writers ],

   task_end => sub {
      my ($mce, $task_id, $task_name) = @_;

      if ($task_name eq 'poller') {
         $setter_q->end();
      }
      elsif ($task_name eq 'setter') {
         $pinger_q->end();
      }
      elsif ($task_name eq 'pinger') {
         $writer_q->end();
      }
   }
};

mce_flow \&poller, \&setter, \&pinger, \&writer;

