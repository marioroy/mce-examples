#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::Worker;
use Storable qw(freeze thaw);

use MCE::Shared 1.811;
use MCE::Hobo;

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

   my $chunk_size = 500;
      $chunk_size =  50 if ( @{ $workload->[1] } < 1500 );
      $chunk_size =   5 if ( @{ $workload->[1] } <  150 );

   my $seq  = MCE::Shared->sequence(
      { bounds_only => 1, chunk_size => 500 }, 0, $#{ $workload->[1] }
   );

   # The bounds_only option is important to have the shared-manager process
   # send the next begin and end values only. Because, it's faster to have
   # the worker do a for ( $beg .. $end ) loop versus obtain each sequence
   # number individualy one at a time.

   my $data = MCE::Shared->array();

   my $parallel = sub {

      while ( my ($beg, $end) = $seq->next ) {
         my %_data;

         for my $pos ($beg .. $end) {
            my $string = $workload->[1][$pos]; chomp($string);
            my $string_size = length($string);
            my $result = '';

            for (my $i = $string_size; $i > 0; $i--) {
               my $letter = substr($string, ($i - 1), 1);
               $result .= $letter;
            }

          # $data->set($pos, "$string: $result\n"); # don't do this
            $_data{$pos} = "$string: $result\n";    # store locally instead
         }

         $data->mset(%_data); # batch update shared-array outside of loop
      }

      # Working with shared data among workers can be fast when batching
      # requests here and there. The result is a reduction in IPC to and
      # from the shared-manager process which is a good thing.

      # Both MCE and MCE::Shared were built with batching capabilities.
      # So, my friend, why not take advantage of it when you can.

      return;
   };

   MCE::Hobo->create($parallel) for (1 .. 4);

   MCE::Hobo->waitall();

   printf( "Job=%s ChunkID=%s NumItems=%s\n",
      $job->handle(), $workload->[0], scalar(@{ $workload->[1] })
   );

   # The non-xs Gearman module doesn't have a way to obtain the job-handle
   # inside the completed callback. Thus, am including here to be able to
   # test the xs and non-xs Gearman modules interchangeably.

   return freeze([ $job->handle(), $workload->[0], join('', $data->vals) ]);
}

