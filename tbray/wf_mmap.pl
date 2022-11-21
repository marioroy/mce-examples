#!/usr/bin/env perl -s

##
## wf.pl -- an implementation of the "wide finder" benchmark.
## Sean O'Rourke, 2007, public domain.
##
## Usage: perl -s wf.pl -J=$N $LOGFILE
##     where $N is the number of workers, and $LOGFILE is the target.
##
## Sys::Mmap no longer works for large input files.
## Divide and conquer update not using Sys::Mmap - May 2022.
##

use strict qw(subs refs);
use warnings;

## no critic (InputOutput::ProhibitBarewordFileHandles)
## no critic (InputOutput::ProhibitTwoArgOpen)

use Time::HiRes qw(time);

$J ||= 8;

my $file = shift;

my $start = time;
my $rx = qr|GET /ongoing/When/\d\d\dx/(\d\d\d\d/\d\d/\d\d/[^ .]+) |;
my %h;
my $n = 0;

if (! $J or $J == 1) {
    # Serial
    open my $IN, '<', $file or die $!;
    while (<$IN>) {
        next unless $_ =~ /$rx/o;
        $h{$1}++;
    }
} else {
    # Parallel
    use Storable qw(store_fd fd_retrieve);

  # use Sys::Mmap;
  # open my $IN, '<', $file or die $!;
  # mmap my $str, 0, PROT_READ, MAP_SHARED, $IN;

    my $size = -s $file;
    my $chunksize = int(($size + $J - 1) / $J);
    my @fhs;
    local $| = 1;
    for my $i (0..$J-1) {
        my $pid = open my $fh, "-|";
        die unless defined $pid;
        if ($pid) {
            push @fhs, $fh;
        } else {

          # my $end = ($i+1) * $chunksize;
          # pos($str) = $i ? index($str, "\n", $end - $chunksize) : 0;
          # $h{$1}++ while $str =~ /$rx/go && pos($str) < $end;

            open my $IN, '<', $file or die $!;
            my $end = ($i+1) * $chunksize;
            if ($i > 0) {
                seek $IN, $end - $chunksize, 0;
                readline $IN;  # skip rest of line
            }
            while (<$IN>) {
                last if tell($IN) > $end;
                next unless $_ =~ /$rx/o;
                $h{$1}++;
            }

            store_fd \%h, \*STDOUT or die "$i can't store!\n";
            exit 0;
        }
    }
    for (0..$#fhs) {
        my $h = fd_retrieve $fhs[$_] or die "I can't load $_\n";
        while (my ($k, $v) = each %$h) {
            $h{$k} += $v;
        }
        close $fhs[$_] or warn "$_ exited weirdly.";
    }
}

my $end = time;

for (sort { $h{$b} <=> $h{$a} } keys %h) {
    print "$h{$_}\t$_\n";
    last if ++$n >= 10;
}

printf "\n## Compute time: %0.03f\n\n",  $end - $start;

