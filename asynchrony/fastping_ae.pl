#!/usr/bin/env perl
###############################################################################
## ----------------------------------------------------------------------------
## Report failing IP addresses using AnyEvent::FastPing.
## Try running on Linux (sudo) if failing under Mac OS X.
##
###############################################################################

use strict;
use warnings;

my $prog_name = $0; $prog_name =~ s{^.*[\\/]}{}g;

use Time::HiRes qw( sleep time );

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::FastPing;
use MCE;

###############################################################################
## ----------------------------------------------------------------------------
## Display usage and exit.
##
###############################################################################

sub usage {

   print <<"::_USAGE_BLOCK_END_::";

NAME
   $prog_name -- Report failing IP addresses using AnyEvent::FastPing

SYNOPSIS
   $prog_name ip_list_file

DESCRIPTION
   The $prog_name script utilizes the chunking nature of MCE and
   AnyEvent::FastPing to obtain a list of failing IP addresses.

   This script requires super-user to run. Failed addresses are
   displayed to standard output.

   The following options are available:

   --max-workers MAX_WORKERS
          Specify number of workers for MCE      Default: auto

   --chunk-size CHUNK_SIZE
          Specify chunk size for MCE             Default: 300

EXAMPLES

   $prog_name --chunk-size 150 --max-workers 6 ip_list_file

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

my $max_workers = 'auto';
my $chunk_size  = 300;
my $skip_args   = 0;

my $list_file;

while ( my $arg = shift @ARGV ) {
   unless ($skip_args) {
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

   $list_file = $arg;
}

usage() unless (defined $list_file);

unless (-e $list_file) {
   print "$prog_name: $list_file: No such file or directory\n";
   exit 2;
}
if (-d $list_file) {
   print "$prog_name: $list_file: Is a directory\n";
   exit 1;
}

###############################################################################
## ----------------------------------------------------------------------------
## Pinger functions for MCE. This requires super-user to run.
##
###############################################################################

my $exit_status = 0;

sub failed_callback
{
   $exit_status = 1;

   return;
}

sub pinger_begin
{
   my ($mce) = @_;

   sleep( $mce->task_wid() * 0.02 );

   $mce->{pinger} = new AnyEvent::FastPing;
   $mce->{pinger}->interval(1/933);
   $mce->{pinger}->max_rtt(3.333);

   return;
}

sub pinger_end
{
   my ($mce) = @_;

   undef $mce->{pinger};

   return;
}

sub pinger_func
{
   my ($mce, $chunk_ref, $chunk_id) = @_;

   my (@ping_list, $binary_address, $format_address, %lookup);
   my $pinger = $mce->{pinger};
   my %pass   = ();
   my @fail   = ();

   ## $chunk_ref points to an array containing $chunk_size items
   ## Since, the list is a file, we need to chomp off the linefeed.

   chomp @{ $chunk_ref };

   ## Ping starts here

   foreach my $ip (@{ $chunk_ref })
   {
      $binary_address = AnyEvent::Socket::parse_address($ip);
      $format_address = AnyEvent::Socket::format_address($binary_address);
      $lookup{$format_address} = $ip;

      push @ping_list, $binary_address;
   }

   my $cv = AnyEvent->condvar;
   my $ping_count = @ping_list;

   $pinger->add_hosts(\@ping_list); $cv->begin;

   $pinger->on_idle( sub {
      $cv->end; $pinger->stop;
   });

   $pinger->on_recv ( sub {
      for (@{ $_[0] }) {
         $format_address = AnyEvent::Socket::format_address($_->[0]);

         $pass{ $lookup{$format_address} } = 1
            if (exists $lookup{$format_address});

         unless (--$ping_count) { $cv->end; $pinger->stop; }
      }
   });

   ## Throttle pinger blasting (configurable via the interval option)
   ## Let pinger process entire chunk all at once

   $mce->yield(); $pinger->start;

   $cv->wait;
   undef $cv;

   ## Store failed hosts/IPs

   for ( @{ $chunk_ref } ) {
      push @fail, "Failed ping: $_\n" unless exists $pass{$_};
   }

   ## Display failed results to STDOUT

   if (@fail > 0) {
      $mce->do('failed_callback');
      $mce->print(@fail);
   }

   return;
}

###############################################################################
## ----------------------------------------------------------------------------
## Parallel pings.
##
###############################################################################

my $mce = MCE->new(
   use_threads => 0,
   user_begin  => \&pinger_begin,
   user_func   => \&pinger_func,
   user_end    => \&pinger_end,
   max_workers => $max_workers,
   chunk_size  => $chunk_size,
   input_data  => $list_file,
   interval    => 0.007,
)->run;

exit $exit_status;

