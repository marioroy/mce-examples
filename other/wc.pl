#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## Word count script similar to the wc binary.
##
## The logic below does not support multi-byte characters. The focus is
## demonstrating Many-Core Engine for Perl. Use this script for large
## file(s).
##
## The usage description was largely ripped off from the wc man page.
##
###############################################################################

use strict;
use warnings;

my $prog_name = $0; $prog_name =~ s{^.*[\\/]}{}g;

sub INIT {
   ## Provide file globbing support under Windows similar to Unix.
   @ARGV = <@ARGV> if ($^O eq 'MSWin32');
}

use IPC::Open2;
use MCE;

###############################################################################
## ----------------------------------------------------------------------------
## Display usage and exit.
##
###############################################################################

sub usage {

   print <<"::_USAGE_BLOCK_END_::";

NAME
   $prog_name -- word, line, and character count

SYNOPSIS
   $prog_name [-clw] [file ...]

DESCRIPTION
   The $prog_name utility displays the number of lines, words, and bytes
   contained in each input file, or standard input (if not file is
   specified) to the standard output.  A line is defined as a string
   of characters delimited by a <newline> character.

   The following options are available:

   --max-workers MAX_WORKERS
          Specify number of workers for MCE   -- default: auto

   --chunk-size CHUNK_SIZE
          Specify chunk size for MCE          -- default: 2 MiB

   -c     Display the number of bytes
   -l     Display the number of lines
   -w     Display the number of words

   When an option is specified, $prog_name, only reports the information
   requested by that option. The order of output always takes the form
   of line, word, byte, and file name. The default action is equivalent
   to specifying the -c -l and -w options.

   If no files are specified, the standard input is used and no file name
   is displayed.  The prompt will accept input until receiving EOF, or
   [^D] in most environments.

EXIT STATUS
   The $prog_name utility exits 0 on success, and >0 if an error occurs.

EXAMPLES
   Count the number of bytes, words and lines in each of the files
   report1 and report2 as well as the totals for both:

         $prog_name -c -w -l report1 report2
         $prog_name -cwl report1 report2
         $prog_name report1 report2

   Count the number of lines: (pass -- to treat following args as files)
         $prog_name -l -- -filename_with_dash

::_USAGE_BLOCK_END_::

   exit 1
}

###############################################################################
## ----------------------------------------------------------------------------
## Define defaults and process command-line arguments.
##
###############################################################################

my $flag = sub { 1; };
my $isOk = sub { (@ARGV == 0 or $ARGV[0] =~ /^-/) ? usage() : shift @ARGV; };

my $chunk_size  = '2m';
my $max_workers = 'auto';
my $skip_args   = 0;

my $c_flag = 0;
my $l_flag = 0;
my $w_flag = 0;

my @files = ();

while ( my $arg = shift @ARGV ) {
   unless ($skip_args) {
      if ($arg eq '-') {
         push @files, $arg;
         next;
      }
      if ($arg =~ m/^-[clw]+$/) {
         while ($arg) {
            my $a = chop($arg);
            $c_flag = $flag->() and next if ($a eq 'c');
            $l_flag = $flag->() and next if ($a eq 'l');
            $w_flag = $flag->() and next if ($a eq 'w');
         }
         next;
      }

      $skip_args   = $flag->() and next if ($arg eq '--');
      $max_workers = $isOk->() and next if ($arg =~ /^--max[-_]workers$/);
      $chunk_size  = $isOk->() and next if ($arg =~ /^--chunk[-_]size$/);

      if ($arg =~ /^--max[-_]workers=(.+)/) {
         $max_workers = $1;
         next;
      }
      if ($arg =~ /^--chunk[-_]size=(.+)/) {
         $chunk_size = $1;
         next;
      }

      usage() if ($arg =~ /^-/);
   }

   push @files, $arg;
}

if ($c_flag + $l_flag + $w_flag == 0) {
   $c_flag = $l_flag = $w_flag = 1;
}

my ($wc_cmd, $wc_args);

if ($^O ne 'cygwin' && $^O ne 'MSWin32') {
   $wc_cmd = (-x '/usr/bin/wc')
           ? '/usr/bin/wc' : ((-x '/bin/wc') ? '/bin/wc' : undef);
}

if (defined $wc_cmd && ($l_flag || $w_flag)) {
   $wc_args  = '-';
   $wc_args .= 'l' if ($l_flag);
   $wc_args .= 'w' if ($w_flag);
}

###############################################################################
## ----------------------------------------------------------------------------
## Configure Many-Core Engine.
##
###############################################################################

## Called once per file (prior to chunking) -- think of awk BEGIN { ... }

sub user_begin {

   my ($mce) = @_;

   $mce->{wk_lines} = 0;
   $mce->{wk_words} = 0;
   $mce->{wk_bytes} = 0;

   use vars qw($wc_pid $wc_out $wc_in);
   our ($wc_pid, $wc_out, $wc_in);

   if (defined $wc_cmd && ($l_flag || $w_flag)) {
      $wc_pid = open2($wc_out, $wc_in, "$wc_cmd $wc_args");
   }

   return;
}

## Called once per chunk of data -- think of forchuck { ... }

sub user_func {

   my ($mce, $chunk_ref, $chunk_id) = @_;
   my $line_count;

   if ($l_flag || $w_flag) {
      if (defined $wc_cmd) {
         syswrite($wc_in, $$chunk_ref);
      }
      else {
         open my $_MEM_FH, '<', $chunk_ref;
         binmode $_MEM_FH;
         1 while <$_MEM_FH>;
         $line_count = $.;
         close $_MEM_FH;

         $mce->{wk_lines} += $line_count;

         if ($w_flag) {
            if (index($$chunk_ref, ' ') >= 0 || index($$chunk_ref, "\t") >= 0) {
               my $words = 0; $words++ while ($$chunk_ref =~ m!\S+!mg);
               $mce->{wk_words} += $words;
            }
            else {
               $mce->{wk_words} += $line_count;
            }
         }
      }
   }

   $mce->{wk_bytes} += length($$chunk_ref) if ($c_flag);

   return;
}

## Called once per file (after chunking) -- think of awk END { ... }

sub user_end {

   my ($mce) = @_;

   if (defined $wc_cmd && ($l_flag || $w_flag)) {
      close $wc_in;

      my $result = <$wc_out>; chomp $result;

      if ($result) {
         if ($l_flag && $w_flag) {
            if ($result =~ m/(\d+)\s+(\d+)/) {
               $mce->{wk_lines} = $1;
               $mce->{wk_words} = $2;
            }
         }
         elsif ($l_flag) {
            $mce->{wk_lines} = $result;
         }
         else {
            $mce->{wk_words} = $result;
         }
      }

      waitpid($wc_pid, 0);
   }

   my %subtotal = (
      'lines' => $mce->{wk_lines},
      'words' => $mce->{wk_words},
      'bytes' => $mce->{wk_bytes}
   );

   $mce->do('main::aggregate_result', \%subtotal);

   return;
}

## Instantiate Many-Core Engine and spawn workers.

my $mce = MCE->new(
   user_begin  => \&user_begin,          ## Called prior to chunking
   user_func   => \&user_func,           ## Think of forchunk { ... }
   user_end    => \&user_end,            ## Called after chunking
   chunk_size  => $chunk_size,
   max_workers => $max_workers,
   use_slurpio => 1
);

###############################################################################
## ----------------------------------------------------------------------------
## Word, line, and character count.
##
###############################################################################

my ($f_lines, $f_words, $f_bytes) = (0, 0, 0);
my ($t_lines, $t_words, $t_bytes) = (0, 0, 0);
my $exit_status = 0;

sub aggregate_result {

   my $subtotal_ref = shift;

   $f_lines += $subtotal_ref->{'lines'};
   $f_words += $subtotal_ref->{'words'};
   $f_bytes += $subtotal_ref->{'bytes'};

   $t_lines += $subtotal_ref->{'lines'};
   $t_words += $subtotal_ref->{'words'};
   $t_bytes += $subtotal_ref->{'bytes'};

   return;
}

sub display_result {

   my ($lines, $words, $bytes, $file) = @_;
   my $result = '';

   $result .= sprintf " %7d", $lines if ($l_flag);
   $result .= sprintf " %7d", $words if ($w_flag);
   $result .= sprintf " %7d", $bytes if ($c_flag);
   $result .= sprintf " %s", $file if (defined $file);

   print $result, "\n";
   return;
}

## Process files, otherwise read from standard input.

if (@files > 0) {
   for my $file (@files) {
      if (! -e $file) {
         print {*STDERR} "$prog_name: $file: No such file or directory\n";
         $exit_status = 2;
      }
      elsif (-d $file) {
         print {*STDERR} "$prog_name: $file: Is a directory\n";
         $exit_status = 1;
      }
      else {
         if ($c_flag && ($l_flag + $w_flag == 0)) {
            $f_bytes  = -s $file;
            $t_bytes += $f_bytes;
         }
         else {
            $mce->process($file);
         }
         display_result($f_lines, $f_words, $f_bytes, $file);
         $f_lines = $f_words = $f_bytes = 0;
      }
   }
   if (@files > 1) {
      display_result($t_lines, $t_words, $t_bytes, 'total');
   }
}
else {
   $mce->process(\*STDIN);
   display_result($f_lines, $f_words, $f_bytes);
}

## Shutdown Many-Core Engine and exit.

$mce->shutdown;
exit $exit_status;

