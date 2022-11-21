#!/usr/bin/env perl
##
#  Derived from chameneos example by Jonathan DePeri and Andrew Rodland.
#    http://benchmarksgame.alioth.debian.org/u64q/program.php
#    ?test=chameneosredux&lang=perl&id=4
#
#  Example using MCE::Shared supporting threads and processes by Mario Roy.
#    https://github.com/marioroy/mce-examples/tree/master/chameneos
##

use 5.010;
use strict;
use warnings;

use MCE::Hobo;
use MCE::Shared;
use Time::HiRes 'time';

die 'No argument given' if not @ARGV;

my %color = ( blue => 1, red => 2, yellow => 4 );
my $start = time;

my ( @colors, @complement );

@colors[values %color] = keys %color;

for my $triple (
  [qw(blue blue blue)],
  [qw(red red red)],
  [qw(yellow yellow yellow)],
  [qw(blue red yellow)],
  [qw(blue yellow red)],
  [qw(red blue yellow)],
  [qw(red yellow blue)],
  [qw(yellow red blue)],
  [qw(yellow blue red)],
) {
  $complement[ $color{$triple->[0]} | $color{$triple->[1]} ] =
    $color{$triple->[2]};
}

my @numbers = qw(zero one two three four five six seven eight nine);

sub display_complements
{
  for my $i (1, 2, 4) {
    for my $j (1, 2, 4) {
      print "$colors[$i] + $colors[$j] -> $colors[ $complement[$i | $j] ]\n";
    }
  }
  print "\n";
}

sub num2words
{
  join ' ', '', map $numbers[$_], split //, shift;
}

# Construct condvars and queues first before other shared objects or in
# any order when IO::FDPass is installed, used by MCE::Shared::Server.

my $meetings  = MCE::Shared->condvar();

my $creatures = MCE::Shared->array();
my $first     = MCE::Shared->scalar(undef);
my $met       = MCE::Shared->array();
my $met_self  = MCE::Shared->array();

sub chameneos
{
  my $id = shift;

  while (1) {
    $meetings->lock();

    unless ($meetings->get()) {
      $meetings->unlock();
      last;
    }

    if (defined (my $val = $first->get())) {
      my ($v1, $v2) = $creatures->mget($val, $id);

      # The pipeline method is helpful for reducing the number
      # of trips to the shared-manager process.

      $creatures->pipeline(
        [ 'set', $val, $v1 | $v2 ],
        [ 'set', $id,  $v1 | $v2 ]
      );

      $met_self->incr($val) if ($val == $id);

      $met->pipeline(
        [ 'incr', $val ],
        [ 'incr', $id  ]
      );

      $meetings->decr();
      $first->set(undef);

      # Unlike threads::shared (condvar) which retains the lock
      # while in the scope, MCE::Shared signal and wait methods
      # must be called prior to leaving the block, due to lock
      # being released upon return.

      $meetings->signal();
    }
    else {
      $first->set($id);
      $meetings->wait();  # ditto ^^
    }
  }
}

sub pall_mall
{
  my $N = shift;
  $creatures->assign(map $color{$_}, @_);
  my @threads;

  print " ", join(" ", @_);
  $meetings->set($N);

  for (0 .. $creatures->len() - 1) {
    $met->set($_, 0);
    $met_self->set($_, 0);
    push @threads, MCE::Hobo->create(\&chameneos, $_);
  }
  for (@threads) {
    $_->join();
  }

  $meetings->set(0);

  for (0 .. $creatures->len() - 1) {
    print "\n".$met->get($_), num2words($met_self->get($_));
    $meetings->incrby($met->get($_));
  }

  print "\n", num2words($meetings->get()), "\n\n";
}

display_complements();

pall_mall($ARGV[0], qw(blue red yellow));
pall_mall($ARGV[0], qw(blue red yellow red yellow blue red yellow red blue));

printf "duration: %0.03f seconds\n", time - $start;

