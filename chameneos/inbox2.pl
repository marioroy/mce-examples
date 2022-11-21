#!/usr/bin/env perl
##
#  Derived from chameneos example by Leon Timmermans.
#    https://github.com/Leont/threads-lite/blob/master/examples/chameneos
#
#  Example using MCE::Inbox supporting threads and processes by Mario Roy.
#    https://github.com/marioroy/mce-examples/tree/master/chameneos
##

BEGIN {
  require Cwd;
  my $prog_dir = Cwd::abs_path($0); $prog_dir =~ s{[\\/][^\\/]*$}{};
  unshift @INC, "$prog_dir/lib";
}

use 5.010;
use strict;
use warnings;

use MCE::Hobo;
use MCE::Inbox;
use Time::HiRes 'time';

die 'No argument given' if not @ARGV;

my @names = map { 'name'.$_ } 0..10;
my $inbox = MCE::Inbox->new(@names);
my $start = time;

my @creature_colors = qw(blue red yellow);
my %complement;

sub complement {
  my ($c1, $c2) = @_;
  return $c1 if $c1 eq $c2;

  if ($c1 eq 'red') {
    $c2 eq 'blue' ? 'yellow' : 'blue';
  }
  elsif ($c1 eq 'blue') {
    $c2 eq 'red'  ? 'yellow' : 'red';
  }
  elsif ($c1 eq 'yellow') {
    $c2 eq 'blue' ? 'red'    : 'blue';
  }
}

sub show_complement {
  foreach my $c1 (@creature_colors) {
    foreach my $c2 (@creature_colors) {
      say "$c1 + $c2 -> ". $complement{$c1,$c2};
    }
  }
  say '';
}

sub spellout {
  my ($n) = @_;
  my @numbers = qw(zero one two three four five six seven eight nine);
  return ' '. join(' ', map { $numbers[$_] } split //, $n);
}

sub print_header {
  my @args = @_;
  say ' ', join ' ', @args;
}

sub run {
  my ($num, $list) = @_;
  my $broker = $names[0];
  print_header(@{$list});

  my @threads =
    map { MCE::Hobo->create(\&cameneos, $broker, $names[$_+1], $list->[$_])
        } 0 .. @{$list} - 1;

  broker($broker, $num);
  cleanup($broker, scalar @{$list}, \@threads);
}

sub cameneos {
  my ($broker, $self, $color) = @_;
  my ($meetings, $metself) = (0, 0);

  my $continue = 1;
  while ($continue) {
    $inbox->send($broker, $self, $color);
    local @_ = $inbox->recv($self);
    if ($_[0] eq 'stop') {
      say $meetings, spellout($metself);
      $inbox->send($broker, $meetings);
      $continue = 0;
    }
    else {
      my ($opid, $ocolor) = @_;
      $metself++ if $opid eq $self;
      $meetings++;
      $color = $complement{$color,$ocolor};
    }
  }
}

sub broker {
  my ($broker, $num) = @_;
  while ($num--) {
    my ($id1) = my @c1 = $inbox->recv($broker);
    my ($id2) = my @c2 = $inbox->recv($broker);
    $inbox->send($id1, @c2);
    $inbox->send($id2, @c1);
  }
}

sub cleanup {
  my ($broker, $num, $threads) = @_;
  my $total_meetings = 0;

  while ($num) {
    local @_ = $inbox->recv($broker);
    if (@_ == 2) {
      my ($id, $color) = @_;
      $inbox->send($id, 'stop');
    }
    else {
      my ($meetings) = @_;
      $total_meetings += $meetings;
      $num--;
    }
  }

  $_->join() for @{$threads};

  say spellout($total_meetings);
  say '';

  return;
}

foreach my $c1 (@creature_colors) {
  foreach my $c2 (@creature_colors) {
    $complement{$c1,$c2} = complement($c1,$c2);
  }
}

show_complement();

run($ARGV[0],[ qw(blue red yellow) ]);
run($ARGV[0],[ qw(blue red yellow red yellow blue red yellow red blue) ]);

printf "duration: %0.03f seconds\n", time - $start;

