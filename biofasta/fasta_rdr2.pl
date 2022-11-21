#!/usr/bin/env perl
###############################################################################
##
## FASTA Reader; parallel iterator mode using mce_flow_f.
##
## Synopsis
##   fasta_rdr2.pl [ /path/to/fastafile.fa [ trim_seq ] ]
##
##   CKSIZE=64m perl fasta_rdr2.pl hg19.fa   0   run with chunk_size => '64m'
##   CKSIZE=4m  perl fasta_rdr2.pl uniref.fa 1   run with chunk_size => '4m'
##
##   time NPROCS=1 CKSIZE=4m ./fasta_rdr2.pl uniref.fa 0 | wc -l
##   time NPROCS=8 CKSIZE=4m ./fasta_rdr2.pl uniref.fa 1 | wc -l
##
##   cat uniref100.fasta | NPROCS=8 CKSIZE=4m perl fasta_rdr2.pl - 0
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
my $cksize = $ENV{CKSIZE} || '2m';

## Process file.

my $file     = shift || \*STDIN;  $file = \*STDIN if $file eq '-';
my $trim_seq = shift || 0;
my $start    = time;

mce_flow_f {
   max_workers => $nprocs, chunk_size => $cksize,
   RS => "\n>", use_slurpio => 1,

}, \&user_func, $file;

printf {*STDERR} "\n## Compute time: %0.03f\n\n", time - $start;

exit;

###############################################################################
##
## Worker function(s).
##
###############################################################################

{
   use constant { ID => 0, DESC => 1, SEQ => 2 };

   ## The user_func block is called once per each input_data chunk.

   sub user_func {
      my ($mce, $slurp_ref, $chunk_id) = @_;

      ## read from scalar reference
      my $next_seq = Fasta::Reader($slurp_ref, $trim_seq);
  
      ## loop through sequences in $slurp_ref
      my ($id, $desc, $seq, $output);

      while (my $fa = &$next_seq()) {
       # ($id, $desc, $seq) = @{ $fa };              ## this passes by value,
       # $output .= "$id\t$desc\n";                  ## consuming extra memory
  
       # $output .= ">$fa->[ID]\n".$fa->[SEQ]."\n";  ## hash-like access, least
         $output .=  "$fa->[ID]\t$fa->[DESC]\n";     ## memory consumption
      }                                                 

      ## send output to STDOUT for this chunk
      MCE->print($output);

      return;
   }
}

