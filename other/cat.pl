#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## Cat script similar to the cat binary.
##
## The logic below only supports -n -u options. The focus is demonstrating
## Many-Core Engine for Perl.
##
## This script was created to show how order can be preserved even though there
## are only 4 shared socket pairs in MCE no matter the number of workers.
##
## Try running with -n option against a large file with long lines. This
## script will out-perform the cat binary in that case.
##
## The usage description was largely ripped off from the cat man page.
##
###############################################################################

use strict;
use warnings;

my $prog_name = $0; $prog_name =~ s{^.*[\\/]}{}g;

sub INIT {
   ## Provide file globbing support under Windows similar to Unix.
   @ARGV = <@ARGV> if ($^O eq 'MSWin32');
}

use MCE 1.807;

###############################################################################
## ----------------------------------------------------------------------------
## Display usage and exit.
##
###############################################################################

sub usage {

   print <<"::_USAGE_BLOCK_END_::";

NAME
   $prog_name -- concatenate and print files

SYNOPSIS
   $prog_name [-nu] [file ...]

DESCRIPTION
   The $prog_name utility reads files sequentially, writing them to the
   standard output. The file operands are processed in command-line
   order. If file is a single dash ('-') or absent, $prog_name reads
   the standard input.

   The following options are available:

   --max-workers MAX_WORKERS
          Specify number of workers for MCE   -- default: auto

   --chunk-size CHUNK_SIZE
          Specify chunk size for MCE          -- default: 2 MiB

   -n     Number the output lines, starting at 1

EXIT STATUS
   The $prog_name utility exits 0 on success, and >0 if an error occurs.

EXAMPLES
   The command:

         $prog_name file1

   will print the contents of file1 to the standard output.

   The command:

         $prog_name file1 file2 > file3

   will sequentially print the contents of file1 and file2 to the file
   file3, truncating file3 if it already exists.

   The command:

         $prog_name file1 - file2 - file3

   will print the contents of file1, print data it receives from the stan-
   dard input until it receives an EOF (typing 'Ctrl/Z' in Windows, 'Ctrl/D'
   in UNIX), print the contents of file2, read and output contents of the
   standard input again, then finally output the contents of file3.

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

my $n_flag = 0;

my @files = ();

while ( my $arg = shift @ARGV ) {
   unless ($skip_args) {
      if ($arg eq '-') {
         push @files, $arg;
         next;
      }
      if ($arg =~ m/^-[nu]+$/) {
         while ($arg) {
            my $a = chop($arg);
            $n_flag = $flag->() and next if ($a eq 'n');
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

if ($n_flag == 0 && $max_workers eq 'auto') {
   $max_workers = 2;
}

###############################################################################
## ----------------------------------------------------------------------------
## Launch Many-Core Engine.
##
###############################################################################

$| = 1; # Important, must flush output immediately.

my $mce = MCE->new(

   chunk_size  => $chunk_size, max_workers => $max_workers,
   init_relay  => 0,
   use_slurpio => 1,

   user_func => sub {
      my ($mce, $chunk_ref, $chunk_id) = @_;

      if ($n_flag) {
         ## Relays the total lines read.

         my $output = ''; my $line_count = ($$chunk_ref =~ tr/\n//);
         my $lines_read = MCE::relay { $_ += $line_count };

         open my $fh, '<', $chunk_ref;
         $output .= sprintf "%6d\t%s", ++$lines_read, $_ while (<$fh>);
         close $fh;

         $output .= ":$chunk_id";
         MCE->do('display_chunk', $output);
      }
      else {
         ## The following is another way to have ordered output. Workers
         ## write directly to STDOUT exclusively without any involvement
         ## from the manager process. The statement(s) between relay_lock
         ## and relay_unlock run serially and most important orderly.

         MCE->relay_lock;
         print $$chunk_ref;
         MCE->relay_unlock;
      }

      return;
   }

)->spawn;

###############################################################################
## ----------------------------------------------------------------------------
## Concatenate and print files
##
###############################################################################

my ($order_id, $lines, %tmp);
my $exit_status = 0;

sub display_chunk {

   ## One can have this receive 2 arguments; $chunk_id and $chunk_data.
   ## However, MCE->freeze is called when more than 1 argument is sent.
   ## For performance, $chunk_id is attached to the end of $_[0].

   my $chunk_id = substr($_[0], rindex($_[0], ':') + 1);
   my $chop_len = length($chunk_id) + 1;

   substr($_[0], -$chop_len, $chop_len, '');

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
}

## Process files, otherwise read from standard input.

if (@files > 0) {
   foreach my $file (@files) {
      $order_id = 1; $lines = 0;
      if ($file eq '-') {
         open(STDIN, '<', ($^O eq 'MSWin32') ? 'CON' : '/dev/tty') or die $!;
         $mce->process(\*STDIN);
      }
      elsif (! -e $file) {
         print {*STDERR} "$prog_name: $file: No such file or directory\n";
         $exit_status = 2;
      }
      elsif (-d $file) {
         print {*STDERR} "$prog_name: $file: Is a directory\n";
         $exit_status = 1;
      }
      else {
         $mce->process($file);
      }
   }
}
else {
   $order_id = 1; $lines = 0;
   $mce->process(\*STDIN);
}

## Shutdown Many-Core Engine and exit.

$mce->shutdown;
exit $exit_status;

