#!/usr/bin/env perl
###############################################################################
##
## FASTA index (.fai) generation for FASTA files.
##
## The original plan was to run CPAN BioUtil::Seq::FastaReader in parallel.
## I wanted to process by records versus lines ($/ = "\n>") for faster
## performance. Created for the investigative Bioinformatics field.
##
## Synopsis
##   fasta_aidx.pl [ /path/to/fastafile.fa ]
##
##   FAIDXC=1   perl fasta_aidx.pl ...  use Inline C for better performance
##   NPROCS=4   perl fasta_aidx.pl ...  run with max_workers => 4
##
##   CKSIZE=64m perl fasta_aidx.pl hg19.fa       run with chunk_size => '64m'
##   CKSIZE=4m  perl fasta_aidx.pl uniref.fa     run with chunk_size => '4m'
##
###############################################################################

use strict;
use warnings;

use Cwd 'abs_path';
use lib abs_path($0 =~ m{^(.*)[\\/]} && $1 || abs_path) . '/include';

use Time::HiRes qw( time );
use MCE::Flow;
use Fasta;

## Enable Inline C if desired.

my $faidx = \&Fasta::Faidx;

if (exists $ENV{FAIDXC} && $ENV{FAIDXC} eq '1') {
   require FastaC; $faidx = \&FastaC::Faidx;
}

## Obtain handle to file.

my $file  = shift || \*STDIN;  $file = \*STDIN if $file eq '-';
my $start = time;
my $output_fh;

if (ref $file) {
   $output_fh = \*STDOUT;   ## Output is sent to STDOUT if reading STDIN
} else {
   die "cannot access $file: $!\n" unless -f $file;
   open($output_fh, '>', "$file.fai") or die "$file.fai: open: $!\n";
}

## Run in parallel via MCE. Pass fh to output iter.

my $nprocs = $ENV{NPROCS} || 2;
my $cksize = $ENV{CKSIZE} || '4m';

print {*STDERR} "Building $file.fai\n" unless ref $file;

mce_flow_f {
   gather => output_iter($output_fh), init_relay => 0,
   max_workers => $nprocs, chunk_size => $cksize,
   RS => "\n>", use_slurpio => 1,

}, \&user_func, $file;

## Finish.

close $output_fh unless ref $file;

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

      my ($output_fh) = @_;
      my %tmp; my $order_id = 1;

      ## One can have this receive 2 arguments; $chunk_id and $chunk_data.
      ## However, MCE->freeze is called when more than 1 argument is sent.
      ## For performance, $chunk_id is attached to the end of $_[0].

      return sub {
         my $chunk_id = substr($_[0], rindex($_[0], ':') + 1);
         my $chop_len = length($chunk_id) + 1;

         substr($_[0], -$chop_len, $chop_len, '');

         if ($chunk_id == $order_id && keys %tmp == 0) {
            ## no need to save in cache if orderly
            print {$output_fh} $_[0];
            $order_id++;
         }
         else {
            ## hold temporarily otherwise
            $tmp{$chunk_id} = $_[0];
            while (1) {
               last unless exists $tmp{$order_id};
               print {$output_fh} delete $tmp{$order_id++};
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
   ## The user_func block is called once per each input_data chunk.

   sub user_func {
      my ($mce, $slurp_ref, $chunk_id) = @_;
      my @output;

      ## run, appends to @output; relay next offset value after running
      ## relaying is orderly and driven by chunk_id behind the scene

      my $acc = $faidx->($slurp_ref, \@output);
      my $off = MCE::relay { $_ += $acc };

      ## update offsets; reader appended 3 items (left, $c3, right)
      ## e.g. "$c1\t$c2\t", $c3, "\t$c4\t$c5\n"

      my $i = 1; my $cnt = scalar @output / 3;

      for (1 .. $cnt) {
         $output[$i] += $off if ($output[$i] >= 0);
         $i += 3;
      }

      ## send output to the manager process

      MCE->gather(join('', @output) .':'. $chunk_id);

      return;
   }
}

