#!/usr/bin/env perl

##
#  Net::Ping (syn) - Like TCP protocol, but with many hosts.
#  Parallel demonstration using MCE::Hobo and MCE::Shared.
#
#  Based on pping.pl example included in Forks::Queue 0.03.
#  https://metacpan.org/pod/Forks::Queue
#
#  ping_syn.pl - ping an entire subnet of 254 IP addresses in parallel
#              - try running as root if Net::Ping (syn) is failing
#
#        usage:  sudo perl_syn ping.pl 192.168.0
#                sudo perl_syn ping.pl
##

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/inc";

use MCE::Hobo 1.817;
use MCE::Shared;

use Delay;
use Net::Ping;
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
    my $p = Net::Ping->new("syn", 2);

    while ( my @nodes = $queue1->dequeue(32) ) {
        my %pass;
        sleep $delay->get;  # throttle, to not blast simultaneously

        $p->ping($_) for ( @nodes );

        while ( (my $host, my $rtt, my $ip) = $p->ack ) {
            $pass{$host} = $pass{$ip} = 1;
        }

        $queue2->enqueue(
            map { exists( $pass{$_} )
                    ? { addr => $_, status => 1 }
                    : { addr => $_, status => 0 }
                } @nodes
        );
    }

    $queue2->enqueue({ finished => $$ });

    $p->close;

    return;
}

