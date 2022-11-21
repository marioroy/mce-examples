#!/usr/bin/env perl

## Asynchronous code from the web and modified for Many-Core parallelism.
## https://gist.github.com/jhthorsen/076157063b4bdaa47a3f
##
## Imagine a load-balancer configured to spread the load (round-robin)
## to ports 9701, 9702, 9703, ..., 970N.

use strict;
use warnings;

use Mojo::Base -strict;
use Mojo::IOLoop;

use MCE::Flow;
use MCE::Shared;

my $id   = MCE::Shared->scalar(0);
my $ncpu = MCE::Util::get_ncpu;

my $mce_task = sub {
   my ($mce) = @_; my ($pid, $wid) = ($mce->pid, $mce->wid);

   my $id = Mojo::IOLoop->server({ port => 9700 + $wid }, sub {
      my ($ioloop, $stream) = @_;
      my ($disconnect, $next_id, $loop_id);

      $next_id = $id->incr();

      $disconnect = sub {
         warn "[$pid:$next_id] client disconnected\n";
         Mojo::IOLoop->remove($loop_id);
      };

      $stream->on(close => $disconnect);
      $stream->on(error => $disconnect);
      $stream->on(read  => sub { $_[0]->write($_[1]); });

      $loop_id = Mojo::IOLoop->recurring(
         5 => sub { $stream->write("[$pid:$next_id] ping!\n"); }
      );
   });

   my $hdl = Mojo::IOLoop->acceptor($id)->handle;

   warn "[$pid:0] listening on ".$hdl->sockhost.":".$hdl->sockport."\n";

   Mojo::IOLoop->start;
};

mce_flow { max_workers => $ncpu }, $mce_task;

