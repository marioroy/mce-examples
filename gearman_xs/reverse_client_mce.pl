#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::XS qw(:constants);
use Gearman::XS::Client;

use Perl::Unsafe::Signals;
use Storable qw(freeze thaw);

use MCE::Flow 1.812;

my (%opts, $host, $port, $client);

if (!getopts('h:p:', \%opts) || scalar @ARGV < 1) {
   print "\nusage: $0 [-h <host>] [-p <port>] <string> [ <string> ... ]\n";
   print "\t-h <host> - job server host\n";
   print "\t-p <port> - job server port\n\n";
   exit(1);
}

$host = $opts{h} || 'localhost';
$port = $opts{p} || 4730;

MCE::Flow->init(
   chunk_size => 3, max_workers => 3,

   user_begin => sub {
      $client = Gearman::XS::Client->new();
      $client->add_server($host, $port);
      $client->set_complete_fn(\&completed_cb);
   },

   user_end => sub {
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
   my $workload = freeze([ $chunk_id, $chunk_ref ]);
   my ($ret, $task) = $client->add_task('reverse', $workload);

   if ($ret != GEARMAN_SUCCESS) {
      MCE->printf(\*STDERR, "%s\n", $client->error());
      MCE->exit(1);
   }

   MCE->printf("Added: %s ChunkID:%s\n", $task->unique(), $chunk_id);
}

MCE::Flow->run(\&parallel, \@ARGV);

MCE::Flow->finish();

exit;

sub completed_cb {
   my ($task) = @_;

   # The non-xs Gearman module receives a scalar reference to the return
   # value only, not the $self object. Therefore, workers include the job
   # handle (not used here) to be able to display it from inside a client
   # script using the non-xs Gearman module.

   my $result = thaw( $task->data() ); # [ job_handle, chunk_id, results ]

   MCE->printf( "Completed: %s ChunkID:%s\n%s\n",
      $task->job_handle(), $result->[1], $result->[2]
   );

   return GEARMAN_SUCCESS;
}

