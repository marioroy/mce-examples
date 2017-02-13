#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::XS qw(:constants);
use Gearman::XS::Client;

use Perl::Unsafe::Signals;
use Storable qw(freeze thaw);

use MCE::Flow;

my (%opts, $host, $port, $client);

if (!getopts('h:p:', \%opts)) {
   print "\nusage: $0 [-h <host>] [-p <port>] < infile.txt\n";
   print "\t-h <host> - job server host\n";
   print "\t-p <port> - job server port\n\n";
   exit(1);
}

$host = $opts{h} || '';
$port = $opts{p} || 0;

MCE::Flow->init(
   chunk_size  => 4000, max_workers => 3,

   user_begin  => sub {
      $client = Gearman::XS::Client->new();
      $client->add_server($host, $port);
      $client->set_complete_fn(\&completed_cb);
   },

   user_end    => sub {
      my $ret; UNSAFE_SIGNALS {
         $ret = $client->run_tasks();
      };
      if ($ret != GEARMAN_SUCCESS) {
         MCE->printf(\*STDERR, "%s\n", $client->error());
         MCE->exit(1);
      }
   }
);

sub parallel {
   my ($mce, $chunk_ref, $chunk_id) = @_;
   my $workload = [ $chunk_id, $chunk_ref ];
   my ($ret, $task) = $client->add_task('reverse', freeze($workload));

   if ($ret != GEARMAN_SUCCESS) {
      MCE->printf(\*STDERR, "%s\n", $client->error());
      MCE->exit(1);
   }

   MCE->printf("Added: %s ChunkID:%s\n", $task->unique(), $chunk_id);
}

MCE::Flow->run_file(\&parallel, \*STDIN);

MCE::Flow->finish();

exit;

sub completed_cb {
   my ($task) = @_;
   my $result = thaw( $task->data() ); # [ chunk_id, results ]

   MCE->printf( "Completed: %s ChunkID:%s\n%s\n",
      $task->job_handle(), $result->[0], $result->[1]
   );

   return GEARMAN_SUCCESS;
}

