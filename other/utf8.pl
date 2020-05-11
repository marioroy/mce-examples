#!/usr/bin/env perl
###############################################################################
# -----------------------------------------------------------------------------
# UTF-8 demonstration.
#
###############################################################################

use strict;
use warnings;

use utf8;
use MCE::Loop 1.868;

binmode \*STDOUT, ':utf8';

# This is based on sample code sent to me by Marcus Smith.
#
# Iterate over @list and output to STDOUT 4 times:
# - from a normal for-loop,
# - MCE->say,
# - MCE->do, and
# - MCE->gather

# Unicode characters.
my @list = ( qw(U Ö Å Ǣ Ȝ), "さあ、私は祈る" );

print "0: for-loop: $_\n" for @list;

MCE::Loop->init(
   max_workers => 3,
   chunk_size  => 'auto',
   gather      => sub { print shift; }
);

sub callback {
   my ($msg) = @_;
   print $msg;
}

mce_loop {
   my $wid = MCE->wid;

   MCE->say("$wid: MCE->say: $_") for @{ $_ };
   MCE->sync;

   MCE->do("callback", "$wid: MCE->do: $_\n") for @{ $_ };
   MCE->sync;

   MCE->gather("$wid: MCE->gather: $_\n") for @{ $_ };

} @list;

print "\n";

