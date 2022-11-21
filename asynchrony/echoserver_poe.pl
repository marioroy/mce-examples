#!/usr/bin/env perl

## Asynchronous code from the web and modified for Many-Core parallelism.
## https://blog.afoolishmanifesto.com/posts/concurrency-and-async-in-perl/
##
## Imagine a load-balancer configured to spread the load (round-robin)
## to ports 9801, 9802, 9803, ..., 980N.

use warnings;
use strict;

use POE qw( Component::Server::TCP );

use MCE::Flow;
use MCE::Shared;

my $id   = MCE::Shared->scalar(0);
my $ncpu = MCE::Util::get_ncpu;

my $mce_task = sub {
   my ($mce) = @_;
   my ($pid, $wid) = ($mce->pid, $mce->wid);

   my $port = 9800 + $wid;

   POE::Component::Server::TCP->new(
      Port => $port,
      Started => sub {
         warn "[$pid:0] listening on 0.0.0.0:$port\n";
      },
      ClientConnected => sub {
         $_[HEAP]{next_id} = $id->incr();
         POE::Kernel->delay( ping => 5 );
      },
      ClientInput => sub {
         my $input = $_[ARG0];
         $_[HEAP]{client}->put( $input );
      },
      ClientDisconnected => sub {
         my $next_id = $_[HEAP]{next_id};
         warn "[$pid:$next_id] client disconnected\n";
         POE::Kernel->delay( ping => undef );
      },

      ## Custom event handlers.
      ## Encapsulated in /(Inline|Object|Package)States/ to avoid
      ## potential conflict with reserved constructor parameters.

      InlineStates => {
         ping => sub {
            my $next_id = $_[HEAP]{next_id};
            $_[HEAP]{client}->put("[$pid:$next_id] ping!");
            POE::Kernel->delay( ping => 5 );
         },
      },
   );

   POE::Kernel->run();
};

mce_flow { max_workers => $ncpu }, $mce_task;

