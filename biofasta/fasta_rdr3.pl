#!/usr/bin/env perl
###############################################################################
##
## FASTA Reader; parallel callback mode using mce_flow_f.
##
## Synopsis
##   fasta_rdr3.pl [ /path/to/fastafile.fa [ trim_seq ] ]
##
##   CKSIZE=64m perl fasta_rdr3.pl hg19.fa   0   run with chunk_size => '64m'
##   CKSIZE=4m  perl fasta_rdr3.pl uniref.fa 1   run with chunk_size => '4m'
##
##   time NPROCS=1 CKSIZE=4m ./fasta_rdr3.pl uniref.fa 0 | wc -l
##   time NPROCS=8 CKSIZE=4m ./fasta_rdr3.pl uniref.fa 1 | wc -l
##
##   cat uniref100.fasta | NPROCS=8 CKSIZE=4m perl fasta_rdr3.pl - 0
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
   gather => output_iter(),

}, \&user_func, $file;

printf {*STDERR} "\n## Compute time: %0.03f\n\n", time - $start;

exit;

###############################################################################
##
## Manager function(s).
##
###############################################################################

{
   ## Iterator for preserving output order.
 
   sub output_iter {

      ## One can have this receive 2 arguments; $chunk_id and $chunk_data.
      ## However, MCE->freeze is called when more than 1 argument is sent.
      ## For performance, $chunk_id is attached to the end of $_[0].

      my %tmp; my $order_id = 1;
 
      return sub {
         my $chunk_id = substr($_[0], rindex($_[0], ':') + 1);
         my $chop_len = length($chunk_id) + 1;

         substr($_[0], -$chop_len, $chop_len, '');   ## trim out chunk_id

         if ($chunk_id == $order_id && keys %tmp == 0) {
            ## no need to save in cache if orderly
            print $_[0];
            $order_id++;
         }
         else {
            ## hold temporarily otherwise
            $tmp{$chunk_id} = $_[0];
            while (1) {
               last unless exists $tmp{$order_id};
               print delete $tmp{$order_id++};
            }
         }
 
         return;
      };
   }
}

###############################################################################
##
## Worker function(s).
##
###############################################################################

{
   use constant { ID => 0, DESC => 1, SEQ => 2 };

   ## Callback function for reader called once per each sequence.

   my $output = '';                                  ## unique, not shared

   sub reader_cb {
    # my ($id, $desc, $seq) = @_;                    ## this passes by value,
    # $output .= "$id\t$desc\n";                     ## consuming extra memory

    # $output .= ">$_[ID]\n". $_[SEQ] ."\n";         ## hash-like access, least
      $output .=  "$_[ID]\t$_[DESC]\n";              ## memory consumption

      return;
   }

   ## The user_func block is called once per each input_data chunk.

   sub user_func {
      my ($mce, $slurp_ref, $chunk_id) = @_;

      ## run, calls reader_cb for each sequence
      Fasta::Reader($slurp_ref, $trim_seq, \&reader_cb);

      ## send output to the manager process
      MCE->gather($output .':'. $chunk_id);          ## attach chunk_id value

      $output = '';                                  ## reset output buffer

      return;
   }
}

