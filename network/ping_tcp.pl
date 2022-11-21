#!/usr/bin/env perl

##
#  Net::Ping (tcp) or system ping command.
#  Parallel demonstration using MCE::Hobo and MCE::Shared.
#
#  Based on pping.pl example included in Forks::Queue 0.03.
#  https://metacpan.org/pod/Forks::Queue
#
#  ping_tcp.pl - ping an entire subnet of 254 IP addresses in parallel
#              - works for non-root user, okay
#
#        usage:  perl ping_tcp.pl 192.168.0
#                perl ping_tcp.pl
##

use strict;
use warnings;

use MCE::Hobo 1.817;
use MCE::Shared;

my $NetPing_avail = eval "use Net::Ping; 1";

my $subnet = $ARGV[0] // "192.168.0";
   $subnet =~ s/\.$//;

my $queue1 = MCE::Shared->queue( fast => 1 );
my $queue2 = MCE::Shared->queue( fast => 1 );

MCE::Hobo->create("work") for 1..32;

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
    my $p;

    if ( $NetPing_avail ) {
        $p = Net::Ping->new("tcp", 2);
    }

    while ( my @nodes = $queue1->dequeue(4) ) {
        foreach my $ip ( @nodes ) {
            my $status = ( $p )
              ? $p->ping($ip)
              : 0 + !system("bash -c 'ping -c 2 -t 2 $ip >/dev/null 2>&1'");
         
            $queue2->enqueue({ addr => $ip, status => $status });
        }
    }

    $queue2->enqueue({ finished => $$ });

    $p->close if $p;

    return;
}

