#!/usr/bin/env perl

## Asynchronous code from the web and modified for Many-Core parallelism.
## https://leonerds-code.blogspot.com/2013/10/parallel-name-resolving-using-ioasync.html

use strict; use warnings;

use Socket qw( getnameinfo NI_NUMERICHOST );
use IO::Async::Loop;
use Data::Dump 'pp';

use MCE::Flow;
use MCE::Shared;

my $all_addrs = MCE::Shared->hash();

my @hosts = qw( www.google.com www.facebook.com www.iana.org );

my $mce_opts = {
   user_begin  => sub { $_[0]->{RES} = IO::Async::Loop->new->resolver },
   user_end    => sub { undef $_[0]->{RES} },
   max_workers => 2,
   chunk_size  => 2,       # e.g. max_workers => 10, chunk_size => 100
};

my $mce_task = sub {
   my ($mce, $chunk_ref, $chunk_id) = @_;
   my $res = $mce->{RES};

   my @futures = map {
      my $host = $_;
      $res->getaddrinfo(
         host     => $host,
         socktype => 'stream',
      )->transform(
         done => sub {
            my @results = @_; my @addrs = map {
               (getnameinfo $_->{addr}, NI_NUMERICHOST)[1]
            } @results;
            $all_addrs->set($host, \@addrs);
            return;
         }
      );
   } @{ $chunk_ref };

   Future->wait_all( @futures )->get;
};

MCE::Flow->run( $mce_opts, $mce_task, @hosts );

print {*STDERR} pp( $all_addrs->export() ), "\n";

