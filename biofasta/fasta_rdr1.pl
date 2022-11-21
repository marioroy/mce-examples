#!/usr/bin/env perl
###############################################################################
##
## FASTA Reader; serial iterator, parallel consumers using mce_flow.
##
## Synopsis
##   fasta_rdr1.pl [ /path/to/fastafile.fa [ trim_seq ] ]
##
##   NPROCS=4 perl fasta_rdr1.pl hg19.fa   0     run with max_workers => 4
##   NPROCS=8 perl fasta_rdr1.pl uniref.fa 1     run with max_workers => 8
##
##   time NPROCS=1 ./fasta_rdr1.pl uniref.fa 0 | wc -l
##   time NPROCS=8 ./fasta_rdr1.pl uniref.fa 1 | wc -l
##
##   cat uniref100.fasta | NPROCS=8 perl fasta_rdr1.pl - 0
##
###############################################################################

use strict;
use warnings;

use Cwd 'abs_path';
use lib abs_path($0 =~ m{^(.*)[\\/]} && $1 || abs_path) . '/include';

use Time::HiRes qw( time );
use MCE::Flow;
use Fasta;

my $nprocs = $ENV{NPROCS} || 2;

## Process file.

my $file     = shift || \*STDIN;  $file = \*STDIN if $file eq '-';
my $trim_seq = shift || 0;
my $start    = time;

mce_flow {
   input_data  => Fasta::Reader($file, $trim_seq),
   max_workers => $nprocs,

}, \&user_func;

printf {*STDERR} "\n## Compute time: %0.03f\n\n", time - $start;

exit;

###############################################################################
##
## Worker function(s).
##
###############################################################################

{
   use constant { ID => 0, DESC => 1, SEQ => 2 };

   ## The user_func block is called once per each iterator request.

   sub user_func {
      my ($mce, $iter_ref, $chunk_id) = @_;

    # my ($id, $desc, $seq) = @{ $iter_ref->[0] };  ## $_ points to ->[0] when
    # my ($id, $desc, $seq) = @{ $_ };              ## chunk_size == 1, default
                                                    ## for input iterators
      my $fa = $iter_ref->[0];

      ## send output to STDOUT for this record

    # MCE->print(">$fa->[ID]\n".$fa->[SEQ]."\n");
      MCE->print("$fa->[ID]\t$fa->[DESC]\n");

      return;
   }
}

