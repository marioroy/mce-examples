#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::Worker;
use Storable qw(freeze thaw);

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

$worker->work() while 1;

sub reverse {
   my ($job) = @_;
   my $workload = thaw( $job->arg() ); # [ chunk_id, chunk_ref ]

   my @data = map {
      my $string = $_; chomp($string);
      my $string_size = length($string);
      my $result = '';

      for (my $i = $string_size; $i > 0; $i--) {
         my $letter = substr($string, ($i - 1), 1);
         $result .= $letter;
      }

      "$string: $result\n";

   } @{ $workload->[1] };

   printf( "Job=%s ChunkID=%s NumItems=%s\n",
      $job->handle(), $workload->[0], scalar(@{ $workload->[1] })
   );

   # The non-xs Gearman module doesn't have a way to obtain the job-handle
   # inside the completed callback. Thus, am including here to be able to
   # test the xs and non-xs Gearman modules interchangeably.

   return freeze([ $job->handle(), $workload->[0], join('', @data) ]);
}

