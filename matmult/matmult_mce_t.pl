#!/usr/bin/env perl

##
## Usage:
##    perl matmult_mce_t.pl 1024 [ n_workers ]     ## Default matrix size 512
##                                                 ## Default n_workers 4
##

use strict;
use warnings;

my $prog_name = $0; $prog_name =~ s{^.*[\\/]}{}g;

use Time::HiRes qw(time);

use PDL;
use PDL::Parallel::threads qw(retrieve_pdls);

use MCE;

###############################################################################
 # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #
###############################################################################

my $tam = @ARGV ? shift : 512;
my $n_workers = @ARGV ? shift : 4;

if ($tam !~ /^\d+$/ || $tam < 2) {
   die "error: $tam must be an integer greater than 1.\n";
}

my $cols = $tam;
my $rows = $tam;

my $step_size = ($tam >= 2048) ? 256 : ($tam >= 1024) ? 128 : 64;

my $mce = configure_and_spawn_mce($n_workers);

my $a = sequence $cols,$rows;
my $b = sequence $rows,$cols;
my $c = zeroes   $rows,$rows;

$a->share_as('left_input');
$b->share_as('right_input');
$c->share_as('output');

my $start = time;

$mce->run(0, {
   sequence => [ 0, $rows - 1, $step_size ]
} );

my $end = time;

$mce->shutdown;

## Print results -- use same pairs to match David Mertens' output.
printf "\n## $prog_name $tam: compute time: %0.03f secs\n\n", $end - $start;

for my $pair ([0, 0], [324, 5], [42, 172], [$rows-1, $rows-1]) {
   my ($col, $row) = @$pair; $col %= $rows; $row %= $rows;
   printf "## (%d, %d): %s\n", $col, $row, $c->at($col, $row);
}

print "\n";

###############################################################################
 # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * #
###############################################################################

sub configure_and_spawn_mce {

   my $n_workers = shift || 8;

   return MCE->new(

      max_workers => $n_workers,

      user_begin  => sub {
         my ($self) = @_;

         ( $self->{l}, $self->{r}, $self->{o} ) = retrieve_pdls(
            'left_input', 'right_input', 'output'
         );
      },

      user_func   => sub {
         my ($self, $seq_n, $chunk_id) = @_;

         my $l = $self->{l};
         my $r = $self->{r};
         my $o = $self->{o};

         my $start = $seq_n;
         my $stop  = $start + $step_size - 1;

         $stop = $rows - 1 if ($stop >= $rows);

         use PDL::NiceSlice;
         $o(:,$start:$stop) .= $l(:,$start:$stop) x $r;
         no PDL::NiceSlice;

         return;
      }

   )->spawn;
}

