#!/usr/bin/env perl

## Asynchronous code from the web and modified for Many-Core parallelism.
## https://blog.afoolishmanifesto.com/posts/concurrency-and-async-in-perl/
##
## Imagine a load-balancer configured to spread the load (round-robin)
## to ports 9501, 9502, 9503, ..., 950N.

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Scalar::Util 'refaddr';

use MCE::Flow;
use MCE::Shared;

my $id   = MCE::Shared->scalar(0);
my $ncpu = MCE::Util::get_ncpu;

my $mce_task = sub {
   my ($mce) = @_;
   my ($pid, $wid) = ($mce->pid, $mce->wid);
   my %handles;

   my $server = tcp_server undef, 9500 + $wid, sub {
      my ($fh, $host, $port) = @_;
      my ($disconnect, $next_id, $hdl);

      $next_id = $id->incr();

      $disconnect = sub {
         my ($hdl) = @_;
         warn "[$pid:$next_id] client disconnected\n";
         delete $handles{ refaddr $hdl };
         $hdl->destroy;
      };

      $hdl = AnyEvent::Handle->new(
         fh       => $fh,
         on_eof   => $disconnect,
         on_error => $disconnect,
         on_read  => sub {
            my ($hdl) = @_;
            $hdl->push_write($hdl->rbuf);
            substr($hdl->{rbuf}, 0) = '';
         },
      );

      $handles{ refaddr $hdl } = $hdl;

      $hdl->{timer} = AnyEvent->timer(
         after    => 5,
         interval => 5,
         cb       => sub {
            $hdl->push_write("[$pid:$next_id] ping!\n")
         },
      );

   }, sub {
      my ($fh, $thishost, $thisport) = @_;
      warn "[$pid:0] listening on $thishost:$thisport\n";
   };

   AnyEvent->condvar->wait();
};

mce_flow { max_workers => $ncpu }, $mce_task;

