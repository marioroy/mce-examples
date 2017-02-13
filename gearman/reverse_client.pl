#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::Client;
use Storable qw(freeze thaw);

my (%opts, $host, $port, $client, $tasks, $chunk_size, $chunk_id);

if (!getopts('h:p:', \%opts) || scalar @ARGV < 1) {
   print "\nusage: $0 [-h <host>] [-p <port>] <string> [ <string> ... ]\n";
   print "\t-h <host> - job server host\n";
   print "\t-p <port> - job server port\n\n";
   exit(1);
}

$host = $opts{h} || 'localhost';
$port = $opts{p} || 4730;

$client = Gearman::Client->new();
$client->job_servers("$host:$port");
$tasks  = $client->new_task_set;

$chunk_size = 3;
$chunk_id   = 0;

while (@ARGV) {
   my @next = splice @ARGV, 0, $chunk_size;
   my $workload = freeze([ ++$chunk_id, \@next ]);

   my $unique = $tasks->add_task(
      'reverse' => $workload, { on_complete => \&completed_cb }
   );

   $unique =~ s!^.*//!!;

   printf("Added %s ChunkID: %s\n", $unique, $chunk_id);
}

$tasks->wait;

exit;

sub completed_cb {
   my $result = thaw(${ shift() }); # [ job_handle, chunk_id, results ]

   printf( "Completed %s ChunkID: %s\n%s\n",
      $result->[0], $result->[1], $result->[2]
   );

   return;
}

