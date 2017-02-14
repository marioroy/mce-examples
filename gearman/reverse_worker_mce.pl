#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::Worker;
use Storable qw(freeze thaw);

use MCE::Map 1.812;

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
   my ($job, $options) = @_;
   my $workload = thaw( $job->arg() ); # [ chunk_id, chunk_ref ]

   MCE::Map->init( chunk_size => 'auto', max_workers => 4 );

   # MCE workers might not persist after running depending on the code.
   # If workers must persist, then place the code inside a subroutine.
   # Call MCE::Map like this:
   #
   # my @data = MCE::Map->run(\&subroutine, @{ $workload->[1] });

   my @data = mce_map {
      my $string = $_; chomp($string);
      my $string_size = length($string);
      my $result = '';

      for (my $i = $string_size; $i > 0; $i--) {
         my $letter = substr($string, ($i - 1), 1);
         $result .= $letter;
      }

      "$string: $result\n";

   } $workload->[1];

   # MCE::Map->finish(); # uncomment to shutdown workers after running

   printf( "Job=%s ChunkID=%s NumItems=%s\n",
      $job->handle(), $workload->[0], scalar(@{ $workload->[1] })
   );

   # The non-xs Gearman module doesn't have a way to obtain the job-handle
   # inside the completed callback. Thus, am including here to be able to
   # test the xs and non-xs Gearman modules interchangeably.

   return freeze([ $job->handle(), $workload->[0], join('', @data) ]);
}

