#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## Process STDIN or FILE via Perl in parallel.
##
## This is by no means a complete script, but rather a "how-to" for folks
## wanting to create their own parallel script.
##
###############################################################################

use strict;
use warnings;

use Cwd 'abs_path';

my ($prog_name, $prog_dir);

BEGIN {
   $prog_name = $0;             $prog_name =~ s{^.*[\\/]}{}g;
   $prog_dir  = abs_path($0);   $prog_dir  =~ s{[\\/][^\\/]*$}{};

   $ENV{PATH} = $prog_dir .($^O eq 'MSWin32' ? ';' : ':'). $ENV{PATH};
}

use Getopt::Long qw(
   :config bundling pass_through no_ignore_case no_auto_abbrev
);

use Scalar::Util qw( looks_like_number );
use Fcntl qw( O_RDONLY );

use MCE::Signal qw( -use_dev_shm );
use MCE::Loop;

###############################################################################
## ----------------------------------------------------------------------------
## Display usage and exit.
##
###############################################################################

sub usage {

   print {*STDERR} <<"::_USAGE_BLOCK_END_::";

NAME
   $prog_name -- process STDIN or FILE via Perl in parallel

SYNOPSIS
   $prog_name [script_options] [FILE]

DESCRIPTION
   The $prog_name script processes STDIN or FILE in parallel. STDIN is read
   unless FILE is specified. Specifing more than 1 file will error.

   The following options are available:

   --RS RECORD_SEPARATOR
          Input record separator              -- default: newline

   --chunk-size CHUNK_SIZE
          Specify chunk size for MCE          -- default: auto
          Can also take a suffix; K/k (kilobytes) or M/m (megabytes).

          Less than or equal to 8192 is the number of records.
          Greater than 8192 is the number of bytes. The maximum
          is 24m by MCE internally.

   --max-workers MAX_WORKERS
          Specify number of workers for MCE   -- default: 8

   --parallel-io
          Enable parallel IO for FILE. This is not recommended if running
          on several nodes simultaneously and reading from the same shared
          storage.

EXIT STATUS
   $prog_name exits 0 on success, and >0 if an error occurs.

EXAMPLES
   Process STDIN (workers request the next chunk from the manager process).

      cat infile | $prog_name --chunk-size=2k >out 2>err
      $prog_name --chunk-size=2k < infile >out 2>err

   Process FILE (workers communicate the next offset among themselves).

      $prog_name --chunk-size=2k infile >out 2>err

::_USAGE_BLOCK_END_::

   exit 1;
}

###############################################################################
## ----------------------------------------------------------------------------
## Define defaults and process command-line arguments. Determine input stream.
##
###############################################################################

my $RS           = $/;
my $chunk_size   = 'auto';
my $max_workers  = 8;
my $parallel_io  = 0;

{
   local $SIG{__WARN__} = sub { };

   GetOptions(
      'RS=s'                      => \$RS,
      'chunk-size|chunk_size=s'   => \$chunk_size,
      'max-workers|max_workers=s' => \$max_workers,
      'parallel-io|parallel_io'   => \$parallel_io
   );

   if ($max_workers !~ /^auto/) {
      unless (looks_like_number($max_workers) && $max_workers > 0) {
         print {*STDERR} "$prog_name: $max_workers: invalid max workers\n";
         exit 2;
      }
   }

   if ($chunk_size !~ /^auto/) {
      if ($chunk_size =~ /^(\d+)K/i) {
         $chunk_size = $1 * 1024;
      }
      elsif ($chunk_size =~ /^(\d+)M/i) {
         $chunk_size = $1 * 1024 * 1024;
      }

      if (!looks_like_number($chunk_size) || $chunk_size < 1) {
         print {*STDERR} "$prog_name: $chunk_size: invalid chunk size\n";
         exit 2;
      }
   }
}

usage() if (@ARGV > 1);

my $input = (defined $ARGV[0]) ? $ARGV[0] : \*STDIN;

if (ref $input eq '') {
   if (! -e $input) {
      print {*STDERR} "$prog_name: $input: No such file or directory\n";
      exit 2;
   }
   if (-d $input) {
      print {*STDERR} "$prog_name: $input: Is a directory\n";
      exit 2;
   }
}

###############################################################################
## ----------------------------------------------------------------------------
## Output function. Define the gather iterator for preserving output order.
##
###############################################################################

my $buf = sprintf('%65536s', '');   ## Create a continuous buffer for the
my $exit_status = 0;                ## output routine.

sub output {

   my ($file, $sendto_fh) = @_;
   my ($fh, $n_read);

   if (-s $file) {
      sysopen($fh, $file, O_RDONLY);

      while (1) {
         $n_read = sysread($fh, $buf, 65536);
         last if $n_read == 0;

         syswrite($sendto_fh, $buf, $n_read);
      }

      close $fh;
   }

   unlink $file;

   return;
}

sub gather_iterator {

   my ($out_fh, $err_fh) = @_;
   my %tmp; my $order_id = 1;

   return sub {
      my ($chunk_id, $path, $status) = @_;

      $tmp{$chunk_id} = $path; 
      $exit_status = $status if ($status > $exit_status);

      while (1) {
         last unless exists $tmp{$order_id};

         $path = delete $tmp{$order_id++};
         output("$path.err", $err_fh);
         output("$path.out", $out_fh);
      }
   };
}

###############################################################################
## ----------------------------------------------------------------------------
## Configure MCE. Process STDIN in parallel afterwards. The mce_loop_f routine
## can take a GLOB reference or a scalar containing the path to the file.
##
###############################################################################

MCE::Loop::init {

   RS => $RS, use_slurpio => 1, parallel_io => $parallel_io,
   chunk_size => $chunk_size, max_workers => $max_workers,

   gather => gather_iterator(\*STDOUT, \*STDERR)
};

mce_loop_f {

   my ($mce, $chunk_ref, $chunk_id) = @_;
   my $path = MCE->tmp_dir .'/'. $chunk_id;
   my $chunk_status = 0;

   open my $out_fh, ">", "$path.out";
   open my $err_fh, ">", "$path.err";

   ## open my $mem_fh, "<", $chunk_ref;   ## $chunk_ref is a scalar ref
   ##                                     ## when use_slurpio => 1
   ## while (<$mem_fh>) {
   ##    print $out_fh $_;                ## Consider appending to an array.
   ## }                                   ## Then write to output handle.
   ##
   ## close $mem_fh;

   print $out_fh $$chunk_ref;             ## (or) write entire chunk

   close $out_fh;
   close $err_fh;

   MCE->gather($chunk_id, $path, $chunk_status);

} $input;

###############################################################################
## ----------------------------------------------------------------------------
## Cleanup and exit.
##
###############################################################################

MCE::Loop::finish;

exit $exit_status;

