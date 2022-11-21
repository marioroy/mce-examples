#!/usr/bin/env perl

## The relay method is for receiving and passing on information. Relay is
## enabled by specifing the init_relay option which takes a hash or array
## reference, or a scalar value. Relaying is orderly and driven by chunk_id
## when processing data, otherwise task_wid. Omitting the code block
## (e.g. MCE::relay) relays forward.
##
## Relaying is not meant for passing big data. The last worker will likely
## stall if exceeding the buffer size for the socket. Not exceeding
## 16 KiB - 7 is safe across all platforms.
##
## Also see examples findnull.pl, cat.pl, or biofasta/fasta_aidx.pl.

use strict;
use warnings;

use MCE::Flow max_workers => 4;

print "\n";

###############################################################################

mce_flow {
   init_relay => { p => 0, e => 0 },      ## Relaying multiple values (HASH)
},
sub {
   my $wid = MCE->wid;

   ## do work
   my $pass = $wid % 3;
   my $errs = $wid % 2;

   ## relay
   my %last_rpt = MCE::relay { $_->{p} += $pass; $_->{e} += $errs };

   MCE->print("$wid: passed $pass, errors $errs\n");

   return;
};

my %results = MCE->relay_final;

print "   passed $results{p}, errors $results{e} final\n\n";

###############################################################################

mce_flow {
   init_relay => [ 0, 0 ],                ## Relaying multiple values (ARRAY)
},
sub {
   my $wid = MCE->wid;

   ## do work
   my $pass = $wid % 3;
   my $errs = $wid % 2;

   ## relay
   my @last_rpt = MCE::relay { $_->[0] += $pass; $_->[1] += $errs };

   MCE->print("$wid: passed $pass, errors $errs\n");

   return;
};

my ($pass, $errs) = MCE->relay_final;

print "   passed $pass, errors $errs final\n\n";

###############################################################################

mce_flow {
   init_relay => 0,                       ## Relaying a single value
},
sub {
   my $wid = MCE->wid;

   ## do work
   my $bytes_read = 1000 + ((MCE->wid % 3) * 3);

   ## relay
   my $last_offset = MCE::relay { $_ += $bytes_read };

   ## output
   MCE->print("$wid: $bytes_read\n");

   return;
};

my $total = MCE->relay_final;

print "   $total size\n\n";

