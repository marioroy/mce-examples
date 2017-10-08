
## Created to demonstrate accessing FASTA data by records, not lines.
## MCE scripts must specify option; RS => "\n>"

use strict;
use warnings;
use bytes;

my $prog_dir;

BEGIN {
   use Cwd 'abs_path';

   $prog_dir = ($0 =~ m{^(.*)[\\/]} && $1 || abs_path);
   $ENV{PERL_INLINE_DIRECTORY} = "${prog_dir}/.Inline";

   mkdir "${prog_dir}/.Inline" unless -d "${prog_dir}/.Inline";
}

package FastaC;

###############################################################################
## Generates output suitable for FASTA (.fai) index files.
###############################################################################

use Inline 'C' => "${prog_dir}/include/fasta_seqlen.c";

sub Faidx {

   my ($file, $to) = @_;
   my $do_iter = (ref $to ne 'ARRAY') ? 1 : 0;

   my ($open_flg, $finished, $first_flg) = (0, 0, 1);
   my ($fh, $pos, $hdr, $seq);

   if (ref $file eq '' || ref $file eq 'SCALAR') {
      open($fh, '<', $file) or die "$file: open: $!\n";
      $open_flg = 1;
   } else {
      $fh = $file;
   }

   my ($c1, $c2, $c3, $c4, $c5, $p1, $p2, $acc, $adj, $errcnt);

   ## $c1 = the name of the sequence
   ## $c2 = the length of the sequence
   ## $c3 = the offset of the first base in the file
   ## $c4 = the number of bases in each fasta line
   ## $c5 = the number of bytes in each fasta line

   $acc = Fasta::_read_to_byte($fh, '>');           ## read to first /^>/m

   ## define the iterator function

   my $iter = sub {
      return if $finished;

      local $/ = "\n>";                             ## input record separator
      while ($seq = <$fh>) {
         if (substr($seq, -1, 1) eq '>') {
            $adj = 1; substr($seq, -1, 1, '');      ## trim trailing ">"
         } else {
            $adj = 0;
         }
         $pos = index($seq, "\n") + 1;              ## header and sequence
         $hdr = substr($seq, 0, $pos);              ## 1st, extract the header
         substr($seq, 0, $pos, '');                 ## trim header afterwards

        ($c1) = ($hdr) =~ /^(\S+)/;                 ## compute initial values
         $c2  = length($seq);
         $c3  = $acc + length($hdr);
         $c5  = index($seq, "\n");
         $acc = $c3 + $c2 + $adj;

         if ($c5 < 0) {                                     ## has no bases
            return [ $c1, 0, -1, 0, 0, $acc ] if $do_iter;  ## return if iter
            push @{$to}, "$c1\t0\t", -1, "\t0\t0\n";        ## append to array
            next;
         }

         $c4  = (substr($seq, $c5 - 1, 1) eq "\r") ? $c5 - 1 : $c5;

         ## scans $seq once; also checks for mismatch in line lengths

         ($c2, $errcnt) = @{ fasta_seqlen($seq, ++$c5) };

         ##

         if ($errcnt) {
            print {*STDERR}
               "SKIPPED: mismatched line lengths within sequence $c1\n";
            next;
         }

         return [ $c1, $c2, $c3, $c4, $c5, $acc ] if $do_iter;  ## iterator
         push @{$to}, "$c1\t$c2\t", $c3, "\t$c4\t$c5\n";        ## array
      }

      close $fh if $open_flg;
      $finished = 1;

      return;
   };

   ## return the iterator itself, otherwise run

   if ($do_iter) {
      return $iter;
   } else {
      1 while $iter->();
      return $acc;
   }
}

1;

