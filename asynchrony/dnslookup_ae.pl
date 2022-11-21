#!/usr/bin/env perl

## Asynchronous code from the web and modified for Many-Core parallelism.
## http://www.pal-blog.de/entwicklung/perl/parallel-dns-lookups-using-anyevent.html

use strict; use warnings;

use AnyEvent;
use AnyEvent::DNS;
use Data::Dump 'pp';

use MCE::Flow;
use MCE::Shared;

my $all_addrs = MCE::Shared->hash();

my @hosts = qw( www.google.com www.facebook.com www.iana.org );

my $mce_opts = {
   user_begin  => sub { $_[0]->{RES} = AnyEvent::DNS::resolver },
   user_end    => sub { undef $_[0]->{RES} },
   max_workers => 2,
   chunk_size  => 2,       # e.g. max_workers => 10, chunk_size => 100
};

my $mce_task = sub {
   my ($mce, $chunk_ref, $chunk_id) = @_;
   my $cv  = AnyEvent->condvar;
   my $res = $mce->{RES};
   my %addrs;

   for my $host ( @{ $chunk_ref } ) {
      $cv->begin; $addrs{$host} = [ ];

      ## Args '*', accept => ['a', 'aaaa'] may be inconsistent.
      ## Thus, obtaining IPv4 first.
      $res->resolve($host, 'a', sub {
         for my $record (@_) {
            push @{ $addrs{$host} }, $record->[4];
         }
         ## Followed by IPv6 next.
         $res->resolve($host, 'aaaa', sub {
            for my $record (@_) {
               push @{ $addrs{$host} }, $record->[4];
            }
            $all_addrs->set($host, delete $addrs{$host});
            $cv->end;
         });
      });
   }

   $cv->wait;
};

MCE::Flow->run( $mce_opts, $mce_task, @hosts );

print {*STDERR} pp( $all_addrs->export() ), "\n";

