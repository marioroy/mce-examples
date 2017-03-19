#!/usr/bin/env perl

##
#  AnyEvent::FastPing - Like TCP protocol, but with many hosts.
#  Parallel demonstration using MCE::Hobo and MCE::Shared.
#
#  Based on pping.pl example included in Forks::Queue 0.03.
#  https://metacpan.org/pod/Forks::Queue
#
#  ping_ae.pl - ping an entire subnet of 254 IP addresses in parallel
#             - important, this script must run as root
#
#       usage:  sudo perl ping_ae.pl 192.168.0
#               sudo perl ping_ae.pl
##

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/inc";

use MCE::Hobo 1.817;
use MCE::Shared;

use Delay;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::FastPing;
use Time::HiRes "sleep";

my $subnet = $ARGV[0] // "192.168.0";
   $subnet =~ s/\.$//;

my $queue1 = MCE::Shared->queue( fast => 1 );
my $queue2 = MCE::Shared->queue( fast => 1 );
my $delay  = MCE::Shared->share( Delay->new(0.15) );

MCE::Hobo->create("work") for 1..4;

$queue1->enqueue( map { "$subnet.$_" } 1..254 );
$queue1->end;

my ($num_alive, $num_pinged) = (0,0);

while ( my $result = $queue2->dequeue ) {
    if ( exists $result->{finished} ) {
        MCE::Hobo->waitone; # call before pending
        $queue2->end unless MCE::Hobo->pending;
        next;
    }
    my ($addr, $status) = ($result->{addr}, $result->{status});

    print "$addr => $status\n";
    $num_alive += $status;
    $num_pinged++;
}

print "Got response from $num_alive out of $num_pinged queried addresses.\n";

exit;

sub work {
    my $p = AnyEvent::FastPing->new;

    $p->interval(1/533), $p->max_rtt(2.0);

    while ( my @nodes = $queue1->dequeue(32) ) {
        my (@ping_list, $binary_addr, $format_addr, %lookup, %pass);

        foreach my $ip ( @nodes ) {
            $binary_addr = AnyEvent::Socket::parse_address($ip);
            $format_addr = AnyEvent::Socket::format_address($binary_addr);
            $lookup{$format_addr} = $ip;

            push @ping_list, $binary_addr;
        }

        my $cv = AnyEvent->condvar;
        my $ping_count = @ping_list;

        $p->add_hosts(\@ping_list), $cv->begin;
        $p->on_idle( sub { $cv->end, $p->stop } );

        $p->on_recv( sub {
            for (@{ $_[0] }) {
                $format_addr = AnyEvent::Socket::format_address($_->[0]);

                $pass{ $lookup{$format_addr} } = 1
                   if (exists $lookup{$format_addr});

                unless (--$ping_count) { $cv->end, $p->stop }
            }
        });

        sleep $delay->get();  # throttle, to not blast simultaneously

        $p->start, $cv->wait, undef $cv;

        $queue2->enqueue(
            map { exists( $pass{$_} )
                    ? { addr => $_, status => 1 }
                    : { addr => $_, status => 0 }
                } @nodes
        );
    }

    $queue2->enqueue({ finished => $$ });

    undef $p;

    return;
}

