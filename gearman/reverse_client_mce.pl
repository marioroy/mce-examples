#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Gearman::Client;
use Storable qw(freeze thaw);

use MCE::Flow 1.812;

my (%opts, $host, $port, $client, $tasks);

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
      $client = Gearman::Client->new();
      $client->job_servers("$host:$port");
      $tasks  = $client->new_task_set;
   },

   user_end => sub {
      $tasks->wait;
   }
);

sub parallel {
   my ($mce, $chunk_ref, $chunk_id) = @_;
   my $workload = freeze([ $chunk_id, $chunk_ref ]);

   my $unique = $tasks->add_task(
      'reverse' => $workload, { on_complete => \&completed_cb }
   );

   $unique =~ s!^.*//!!;

   MCE->printf("Added: %s ChunkID:%s\n", $unique, $chunk_id);
}

MCE::Flow->run(\&parallel, \@ARGV);

MCE::Flow->finish();

exit;

sub completed_cb {
   my $result = thaw(${ shift() }); # [ job_handle, chunk_id, results ]

   MCE->printf( "Completed: %s ChunkID:%s\n%s\n",
      $result->[0], $result->[1], $result->[2]
   );

   return;
}

