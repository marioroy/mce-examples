#line 2 "./include/fasta_seqlen.c"
//#############################################################################
// ----------------------------------------------------------------------------
// C source for returning the sequence length in a string including error
// checking for mismatch in line lengths.
//
// my $ret = fasta_seqlen($str, $firstlen);
// ## seqlen: $ret->[0]
// ## errcnt: $ret->[1]    > 0  e.g. length mismatch among lines
//
//#############################################################################

#include <stdint.h>

SV * fasta_seqlen(SV *str_sv, SV *firstlen_sv)
{
   AV *ret           = newAV();
   const char *str   = SvPVX(str_sv);
   uint32_t firstlen = SvUV(firstlen_sv);
   uint32_t strsize  = SvCUR(str_sv);

   uint32_t lastline, linelen, seqlen, blank, errcnt;
   lastline = linelen = seqlen = blank = errcnt = 0;

   while (strsize--) {
      linelen++;
      if (*str > ' ') {
         seqlen++;
      }
      else if (*str == '\r') {
         // filter out cr from nl calculations
         linelen--;
      }
      else if (*str == '\n') {
         if (linelen == 1) {
            blank++;
         }
         else if (blank && linelen > 1) {
            errcnt++;
         }
         else if (linelen != firstlen) {
            errcnt++; lastline = 1;
         }
         else {
            lastline = 0;
         }
         linelen = 0;
      }
      str++;
   }

   if (lastline == 1 && errcnt == 1)
      errcnt--;

   av_push(ret, newSVuv(seqlen));
   av_push(ret, newSVuv(errcnt));

   // ret = [ seqlen, errcnt ]
   return newRV_noinc((SV*) ret);
}

