
## Created to demonstrate accessing FASTA data by records, not lines.
## MCE scripts must specify option; RS => "\n>"

use strict;
use warnings;
use bytes;

package Fasta;

###############################################################################
## Generates output suitable for FASTA (.fai) index files.
###############################################################################

sub Faidx {

   my ($file, $to) = @_;
   my $do_iter = (ref $to ne 'ARRAY') ? 1 : 0;

   my ($open_flg, $finished, $first_flg) = (0, 0, 1);
   my ($fh, $pos, $hdr, $seq);

   if (ref $file eq '' || ref $file eq 'SCALAR') {
      open($fh, '<', $file) or die "$file: open: !\n";
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

         ## scans $seq twice (index and tr); thus the reason for FastaC

         my @a;  $p1 = $c5 + 1; $errcnt = 0;       ## start on 2nd bases line

         while ($p1 < $c2) {                       ## collect line lengths
            $p2 = index($seq, "\n", $p1);
            push @a, $p2 - $p1;
            $p1 = $p2 + 1;
         }

         if (scalar @a) {
            pop @a while ($a[-1] == 0);            ## pop trailing blank lines
            pop @a;                                ## pop last line w/ bases

            foreach (@a) {                         ## any length mismatch?
               $errcnt++ if $_ != $c5;
            }
         }

         $seq =~ tr/\t\r\n //d;                    ## trim white space
         $c2  =  length($seq);
         $c5++;

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

###############################################################################
## General FASTA reader extracting ID, description, and sequence.
###############################################################################

sub Reader {

   my ($file, $trim_seq, $callback) = @_;
   my $do_iter = (ref $callback ne 'CODE') ? 1 : 0;

   my ($open_flg, $finished) = (0, 0);
   my ($fh, $pos, $hdr, $seq, $id, $desc);

   if (ref $file eq '' || ref $file eq 'SCALAR') {
      open($fh, '<', $file) or die "$file: open: $!\n";
      $open_flg = 1;
   } else {
      $fh = $file;
   }

   _read_to_byte($fh, '>');                         ## read to first /^>/m

   ## define the iterator function

   my $iter = sub {
      return if $finished;

      local $/ = "\n>";                             ## input record separator
      while ($seq = <$fh>) {
         if (substr($seq, -1, 1) eq '>') {
            substr($seq, -1, 1, '');                ## trim trailing ">"
         }
         $pos = index($seq, "\n") + 1;              ## header and sequence
         $hdr = substr($seq, 0, $pos - 1);          ## 1st, extract the header
         substr($seq, 0, $pos, '');                 ## trim header afterwards

         chop $hdr if substr($hdr, -1, 1) eq "\r";  ## trim trailing "\r"
         $seq =~ tr/\t\r\n //d if $trim_seq;        ## trim white space

         if (($pos = index($hdr, ' ')) > 0) {       ## id and description
            $id = substr($hdr, 0, $pos);
            $desc = substr($hdr, $pos + 1);
         } else {
            $id = $hdr;
            $desc = '';
         }

         return [ $id, $desc, $seq ] if $do_iter;   ## iterator, otherwise call
         $callback->($id, $desc, $seq);             ## callback function
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
      return;
   }
}

###############################################################################
## Private function(s).
###############################################################################

sub _read_to_byte {

   my ($fh, $byte) = @_;
   my ($bytes, $line_pos) = (0, 0);

   local $/ = \1;                                   ## read one byte including
   while (<$fh>) {                                  ## the first /^$byte/m
      $bytes++;
      last if ($line_pos++ == 0 && $_ eq $byte);
      $line_pos = 0 if ($_ eq "\n");
   }

   return $bytes;
}

1;

