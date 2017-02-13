#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::XS qw(:constants);
use Gearman::XS::Worker;

use Perl::Unsafe::Signals;
use Storable qw(freeze thaw);

use MCE;
use MCE::Candy;

my (%opts, $host, $port, $worker);

if (!getopts('h:p:', \%opts)) {
   print "\nusage: $0 [-h <host>] [-p <port>]\n";
   print "\t-h <host> - job server host\n";
   print "\t-p <port> - job server port\n\n";
   exit(1);
}

$host = $opts{h} || '';
$port = $opts{p} || 0;

$worker = Gearman::XS::Worker->new();
$worker->add_server($host, $port);

my $ret = $worker->add_function('reverse', 0, \&reverse, 0);

if ($ret != GEARMAN_SUCCESS) {
   printf(STDERR "%s\n", $worker->error());
}

my @results;

my $mce = MCE->new(
   chunk_size  => 500,
   max_workers => 4,

   user_func   => sub {
      my ($mce, $mce_chunk_ref, $mce_chunk_id) = @_;
      my $output = '';  chomp @{ $mce_chunk_ref };

      for my $string ( @{ $mce_chunk_ref } ) {
         my $string_size = length($string);
         my $result = '';

         for (my $i = $string_size; $i > 0; $i--) {
            my $letter = substr($string, ($i - 1), 1);
            $result .= $letter;
         }

         $output .= "$string: $result $$\n";
      }

      MCE->gather($mce_chunk_id, $output);
   }
)->spawn();

while (1) {
   UNSAFE_SIGNALS {
      $ret = $worker->work();
   };
   if ($ret != GEARMAN_SUCCESS) {
      printf(STDERR "%s\n", $worker->error());
   }
}

sub reverse {
   my ($job, $options) = @_;
   my $workload = thaw( $job->workload() ); # [ chunk_id, chunk_ref ]

   $mce->process(
      { gather => MCE::Candy::out_iter_array(\@results) },
      $workload->[1]
   );
   printf( "Job=%s ChunkID=%s NumItems=%s\n",
      $job->handle(), $workload->[0], scalar(@{ $workload->[1] })
   );

   # empty @results by splicing so ready for the next run
   return freeze([ $workload->[0], join('', splice(@results, 0)) ]);
}

