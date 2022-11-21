#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## This script outputs line numbers containing null values.
## Matches on regular expressions:  /\|\|/, /\|\t\s*\|/, or /\| \s*\|/
## Null value findings are reported to STDERR.
##
## Slurp IO in MCE is extremely fast. So, no matter how many workers
## you give to the problem, only a single worker slurps the next chunk
## at a given time. You get "sustained" sequential IO plus the workers
## for parallel processing.
##
## usage: findnull.pl [-l] datafile
##        findnull.pl wc.pl
##
###############################################################################

use strict;
use warnings;

my $prog_name = $0; $prog_name =~ s{^.*[\\/]}{}g;

sub INIT {
   ## Provide file globbing support under Windows similar to Unix.
   @ARGV = <@ARGV> if ($^O eq 'MSWin32');
}

use MCE;

###############################################################################
## ----------------------------------------------------------------------------
## Display usage and exit.
##
###############################################################################

sub usage {

   print <<"::_USAGE_BLOCK_END_::";

NAME
   $prog_name -- report line numbers containing null values

SYNOPSIS
   $prog_name [-l] file

DESCRIPTION
   The $prog_name script displays the line number containing null value(s).
   A null value is a match on /\\|\\|/ or /\\|\\s+\\|/.

   The following options are available:

   --max-workers MAX_WORKERS
          Specify number of workers for MCE   -- default: auto

   --chunk-size CHUNK_SIZE
          Specify chunk size for MCE          -- default: 8 MiB

   -l     Display the number of lines for the file

EXIT STATUS
   The $prog_name utility exits 0 on success, and >0 if an error occurs.

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

my $chunk_size  = '8m';
my $max_workers = 'auto';
my $skip_args   = 0;

my $l_flag = 0;
my $file;

while ( my $arg = shift @ARGV ) {
   unless ($skip_args) {
      $l_flag      = $flag->() and next if ($arg eq '-l');

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

   $file = $arg;
}

usage() unless (defined $file);

unless (-e $file) {
   print "$prog_name: $file: No such file or directory\n";
   exit 2;
}
if (-d $file) {
   print "$prog_name: $file: Is a directory\n";
   exit 1;
}

## It is faster to pattern match separately versus combining them
## into one regex delimited by '|'.

my @patterns = ('\|\|', '\|\t\s*\|', '\| \s*\|');
my $re = '(?:' . join('|', @patterns) . ')';

$re = qr/$re/;

## Report line numbers containing null values.
## Display the total lines read.

my $mce = MCE->new(
   chunk_size => $chunk_size, max_workers => $max_workers,
   input_data => $file, gather => preserve_order(),
   user_func  => \&user_func, use_slurpio => 1,
   init_relay => 0, parallel_io => 1
)->run;

if ($l_flag) {
   my $total_lines = MCE->relay_final;
   print "$total_lines $file\n" if ($l_flag);
}

exit;

###############################################################################
## ----------------------------------------------------------------------------
## Manager function(s).
##
###############################################################################

## Output iterator for gather for preserving output order.

sub preserve_order {

   my %tmp; my $order_id = 1;

   return sub {
      my ($chunk_id, $output_ref) = @_;

      if ($chunk_id == $order_id && keys %tmp == 0) {
         ## no need to save in cache if orderly
         print STDERR ${ $output_ref };
         $order_id++;
      }
      else {
         ## hold temporarily otherwise
         $tmp{$chunk_id} = $output_ref;
         while (1) {
            last unless exists $tmp{$order_id};
            print STDERR ${ delete $tmp{$order_id++} };
         }
      }

      return;
   };
}

###############################################################################
## ----------------------------------------------------------------------------
## Worker function(s).
##
###############################################################################

## The user_func block is called once per each input_data chunk.

sub user_func {

   my ($mce, $chunk_ref, $chunk_id) = @_;
   my ($found_match, $line_count, @lines);

   ## Check each regex individually -- faster than (?:...|...|...)
   ## This is optional, was done to quickly determine for any patterns.

   for (0 .. @patterns - 1) {
      if ($$chunk_ref =~ /$patterns[$_]/) {
         $found_match = 1;
         last;
      }
   }

   ## Slurp IO is enabled. $chunk_ref points to the raw scalar chunk.
   ## Each worker receives a chunk relatively fast.

   open my $_MEM_FH, '<', $chunk_ref;
   binmode $_MEM_FH;

   if ($found_match) {               ## append line number(s) if found match
      my ($re1, $re2, $re3) = @patterns;
      while (<$_MEM_FH>) {
       # push @lines, $. if (/$re/);
         push @lines, $. if /$re1/ or /$re2/ or /$re3/;
      }
   }
   else {                            ## read quickly otherwise
      1 while (<$_MEM_FH>);
   }

   $line_count = $.;                 ## obtain number of lines read
   close $_MEM_FH;

   ## Relaying is orderly and driven by chunk_id when processing data, otherwise
   ## task_wid. Only the first sub-task is allowed to relay information.

   ## Relay the total lines read. $_ is same as $lines_read inside the block.
   ## my $lines_read = MCE->relay( sub { $_ += $line_count } );

   my $lines_read = MCE::relay { $_ += $line_count };

   ## Gather output.

   my $output = '';

   for (@lines) {
      $output .= "NULL value at line ".($_ + $lines_read)." in $file\n";
   }

   MCE->gather($chunk_id, \$output);

   return;
}

