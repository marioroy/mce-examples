#!/usr/bin/env perl

## Asynchronous code from the web and modified for Many-Core parallelism.
## https://blog.afoolishmanifesto.com/posts/concurrency-and-async-in-perl/
##
## Imagine a load-balancer configured to spread the load (round-robin)
## to ports 9601, 9602, 9603, ..., 960N.

use strict;
use warnings;

use IO::Async::Loop;
use IO::Async::Timer::Periodic;

use MCE::Flow;
use MCE::Shared;

my $id   = MCE::Shared->scalar(0);
my $ncpu = MCE::Util::get_ncpu;

my $mce_task = sub {
   my ($mce) = @_; my ($pid, $wid) = ($mce->pid, $mce->wid);

   my $loop = IO::Async::Loop->new;

   my $server = $loop->listen(
      host     => '0.0.0.0',
      socktype => 'stream',
      service  => 9600 + $wid,

      on_stream => sub {
         my $stream  = shift;
         my $next_id = $id->incr();

         $stream->configure(
            on_read => sub {
               my ($self, $buffref, $eof) = @_;
               $self->write($$buffref); $$buffref = '';
               if ($eof) {
                  warn "[$pid:$next_id] client disconnected\n";
                  $self->close_now;
               }
               return 0;
            },
         );
         $stream->add_child(
            IO::Async::Timer::Periodic->new(
               interval => 5, on_tick => sub {
                  my ($self) = @_;
                  $self->parent->write("[$pid:$next_id] ping!\n")
               },
            )->start
         );

         $loop->add( $stream );
      },

      on_resolve_error => sub { die "Cannot resolve - $_[1]\n"; },
      on_listen_error  => sub { die "Cannot listen - $_[1]\n"; },

      on_listen => sub {
         my ($s) = @_;
         warn "[$pid:0] listening on ".$s->sockhost.":".$s->sockport."\n";
      },

   );

   $loop->run;
};

mce_flow { max_workers => $ncpu }, $mce_task;

