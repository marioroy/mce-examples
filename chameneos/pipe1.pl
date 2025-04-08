#!/usr/bin/env perl
##
#  Derived from chameneos example by Leon Timmermans.
#    https://github.com/Leont/threads-lite/blob/master/examples/chameneos
#
#  Example using MCE::Channel supporting threads and processes by Mario Roy.
#    https://github.com/marioroy/mce-examples/tree/master/chameneos
##

BEGIN {
  require Cwd;
  my $prog_dir = Cwd::abs_path($0); $prog_dir =~ s{[\\/][^\\/]*$}{};
  unshift @INC, "$prog_dir/lib";
}

use strict;
use warnings;

use threads;
use MCE::Channel 1.878;
use Time::HiRes 'time';

die 'No argument given' if not @ARGV;

# synchronization: creatures communicate on channel 0 to broker
my @chnls = map { MCE::Channel->new( impl => 'PipeFast' ) } 0..10;

# colors and matching
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

foreach my $c1 (@creature_colors) {
  foreach my $c2 (@creature_colors) {
    $complement{$c1,$c2} = complement($c1,$c2);
  }
}

# reporting
sub show_complement {
  foreach my $c1 (@creature_colors) {
    foreach my $c2 (@creature_colors) {
      print "$c1 + $c2 -> ". $complement{$c1,$c2} ."\n";
    }
  }
  print "\n";
}

sub spellout {
  my ($n) = @_;
  my @numbers = qw(zero one two three four five six seven eight nine);
  return ' '. join(' ', map { $numbers[$_] } split //, $n);
}

# the zoo
sub creature {
  my ($my_id, $color) = @_;
  my ($meetings, $metself) = (0, 0);

  my $continue = 1;
  while ($continue) {
    $chnls[0]->send("$my_id $color");
    local @_ = split / /, $chnls[$my_id]->recv();
    if ($_[0] eq 'stop') {
      # leave game
      print $meetings, spellout($metself), "\n";
      $chnls[0]->send($meetings);
      $continue = 0;
    }
    else {
      # save my results
      my ($oid, $ocolor) = @_;
      $metself++ if $oid eq $my_id;
      $meetings++;
      $color = $complement{$color,$ocolor};
    }
  }
}

sub broker {
  my ($n, $nthrs) = @_;
  my $total_meetings = 0;

  while ($n--) {
    # await two creatures
    my ($id1) = my @c1 = split / /, $chnls[0]->recv();
    my ($id2) = my @c2 = split / /, $chnls[0]->recv();
    # registration, exchange colors
    $chnls[$id1]->send("@c2");
    $chnls[$id2]->send("@c1");
  }

  while ($nthrs) {
    local @_ = split / /, $chnls[0]->recv();
    if (@_ == 2) {
      # notify stop game
      my ($id, $color) = @_;
      $chnls[$id]->send('stop');
    }
    else {
      # tally meetings
      my ($meetings) = @_;
      $total_meetings += int($meetings);
      $nthrs--;
    }
  }

  return $total_meetings;
}

# game
sub pall_mall {
  my ($n, $colors) = @_;
  print ' ', join(' ', @{$colors}), "\n";

  my @thrs =
    map { threads->create(\&creature, $_+1, $colors->[$_])
        } 0 .. @{$colors} - 1;

  my $total_meetings = broker($n, scalar @thrs);

  $_->join() for @thrs;

  print spellout($total_meetings), "\n";
  print "\n";
}

my $start = time;

show_complement();
pall_mall($ARGV[0],[ qw(blue red yellow) ]);
pall_mall($ARGV[0],[ qw(blue red yellow red yellow blue red yellow red blue) ]);

printf "duration: %0.03f seconds\n", time - $start;

