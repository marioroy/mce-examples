#!/usr/bin/env perl

use strict;
use warnings;

use MCE::Mutex;
use MCE::Flow max_workers => 4;

print "## running a\n";
my $a = MCE::Mutex->new;

mce_flow sub {
   $a->lock;

   ## access shared resource
   my $wid = MCE->wid; MCE->say($wid); sleep 1;

   $a->unlock;
};

print "## running b\n";
my $b = MCE::Mutex->new;

mce_flow sub {
   $b->synchronize( sub {

      ## access shared resource
      my ($wid) = @_; MCE->say($wid); sleep 1;

   }, MCE->wid );
};

