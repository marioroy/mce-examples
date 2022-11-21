#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::XS qw(:constants);
use Gearman::XS::Client;

use Perl::Unsafe::Signals;
use Storable qw(freeze thaw);

use MCE::Shared 1.811;
use MCE::Hobo;

my (%opts, $host, $port);

if (!getopts('h:p:', \%opts) || scalar @ARGV < 1) {
   print "\nusage: $0 [-h <host>] [-p <port>] <string> [ <string> ... ]\n";
   print "\t-h <host> - job server host\n";
   print "\t-p <port> - job server port\n\n";
   exit 1;
}

$host = $opts{h} || 'localhost';
$port = $opts{p} || 4730;

mce_open my $OUT, ">", \*STDOUT;    # Create shared output/error handles
mce_open my $ERR, ">", \*STDERR;

my $db = MCE::Shared->minidb();     # A very lightweight NOSQL memory DB

my $chunk_size = 3;

$db->hset("input", chunk_id => 0);  # Insert into mini DB, this is fast
$db->lassign("input", @ARGV);

@ARGV = ();

sub parallel {
   my ($client, $ret);

   ## begin

   $client = Gearman::XS::Client->new();
   $client->add_server($host, $port);
   $client->set_complete_fn(\&completed_cb);

   ## loop

   while (1) {

      my ($chunk_id, @next) = $db->pipeline_ex(   # Atomic operation
         [ "hincr",   "input", "chunk_id"     ],
         [ "lsplice", "input", 0, $chunk_size ]
      );

      last unless @next;

      my $workload = freeze([ $chunk_id, \@next ]);
      my ($ret, $task) = $client->add_task("reverse", $workload);

      if ($ret != GEARMAN_SUCCESS) {
         printf({$ERR} "%s\n", $client->error());
         MCE::Hobo->exit(1);
      }

      printf({$OUT} "Added: %s ChunkID:%s\n", $task->unique(), $chunk_id);
   }

   ## end

   UNSAFE_SIGNALS {
      $ret = $client->run_tasks();
   };
   if ($ret != GEARMAN_SUCCESS) {
      printf({$ERR} "%s\n", $client->error());
      MCE::Hobo->exit(1);
   }

   return;
}

MCE::Hobo->create("parallel") for (1 .. 3);

MCE::Hobo->waitall();

exit;

sub completed_cb {
   my ($task) = @_;

   # The non-xs Gearman module receives a scalar reference to the return
   # value only, not the $self object. Therefore, workers include the job
   # handle (not used here) to be able to display it from inside a client
   # script using the non-xs Gearman module.

   my $result = thaw( $task->data() ); # [ job_handle, chunk_id, results ]

   printf({$OUT} "Completed: %s ChunkID:%s\n%s\n",
      $task->job_handle(), $result->[1], $result->[2]
   );

   return GEARMAN_SUCCESS;
}

