#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::Worker;
use Storable qw(freeze thaw);

use MCE 1.812;
use MCE::Candy;

my (%opts, $host, $port, $worker);

if (!getopts('h:p:', \%opts)) {
   print "\nusage: $0 [-h <host>] [-p <port>]\n";
   print "\t-h <host> - job server host\n";
   print "\t-p <port> - job server port\n\n";
   exit(1);
}

$host = $opts{h} || 'localhost';
$port = $opts{p} || 4730;

$worker = Gearman::Worker->new();
$worker->job_servers("$host:$port");
$worker->register_function("reverse", \&reverse);

my $mce = MCE->new(
   max_workers => 4,
   chunk_size  => 500,
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

         $output .= "$string: $result\n";
      }

      MCE->gather($mce_chunk_id, $output);
   }
)->spawn();

$worker->work() while 1;

sub reverse {
   my ($job, $options) = @_;
   my $workload = thaw( $job->arg() ); # [ chunk_id, chunk_ref ]
   my @results;

   # MCE workers persist after running

   $mce->process(
      { gather => MCE::Candy::out_iter_array(\@results) },
      $workload->[1]
   );

   printf( "Job=%s ChunkID=%s NumItems=%s\n",
      $job->handle(), $workload->[0], scalar(@{ $workload->[1] })
   );

   # The non-xs Gearman module doesn't have a way to obtain the job-handle
   # inside the completed callback. Thus, am including here to be able to
   # test the xs and non-xs Gearman modules interchangeably.

   return freeze([ $job->handle(), $workload->[0], join('', @results) ]);
}

