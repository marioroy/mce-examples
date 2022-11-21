#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::Client;
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
   my ($client, $tasks);

   ## begin

   $client = Gearman::Client->new();
   $client->job_servers("$host:$port");
   $tasks  = $client->new_task_set;

   ## loop

   while (1) {

      my ($chunk_id, @next) = $db->pipeline_ex(   # Atomic operation
         [ "hincr",   "input", "chunk_id"     ],
         [ "lsplice", "input", 0, $chunk_size ]
      );

      last unless @next;

      my $workload = freeze([ $chunk_id, \@next ]);

      my $unique = $tasks->add_task(
         'reverse' => $workload, { on_complete => \&completed_cb }
      );

      $unique =~ s!^.*//!!;

      printf({$OUT} "Added: %s ChunkID:%s\n", $unique, $chunk_id);
   }

   ## end

   $tasks->wait;

   return;
}

MCE::Hobo->create("parallel") for (1 .. 3);

MCE::Hobo->waitall();

exit;

sub completed_cb {
   my $result = thaw(${ shift() }); # [ job_handle, chunk_id, results ]

   printf({$OUT} "Completed: %s ChunkID:%s\n%s\n",
      $result->[0], $result->[1], $result->[2]
   );

   return;
}

