#!/usr/bin/env perl

use strict;
use warnings;

use Net::Pcap;

# ------------------------------------------------------------
# from Net::Pcap/t/samples

my $user_data = "user_data";

my $dmp_file = ( unpack("h*", pack("s", 1)) =~ /01/ )
    ? "samples/ping-ietf-20pk-be.dmp"
    : "samples/ping-ietf-20pk-le.dmp";

# ------------------------------------------------------------

use MCE::Flow 1.818;  # or later
use MCE::Queue;

my $Q = MCE::Queue->new( await => 1, fast => 1 );

my $queue_limit   = 100;  # set to 0 for unlimited
my $max_consumers = 4;

MCE::Flow->init(
    max_workers => [ 1, $max_consumers ],
    task_name   => [ 'provider', 'consumer' ],
    user_end    => sub {
        my ( $mce, $task_id, $task_name ) = @_;
        if ( $task_name eq 'provider' ) {
            $Q->end();
        }
    }
);

MCE::Flow->run( \&provider, \&consumer );
MCE::Flow->finish;

exit(0);

# ------------------------------------------------------------

sub provider {
    my ($mce) = @_;
    my ($count, $err) = (0);

    my $pcap = Net::Pcap::open_offline($dmp_file, \$err) or do {
        warn "open error: $err\n";
        return;
    };

    my $callback = sub {
        my ($user_data, $header, $packet) = @_;
        $Q->enqueue([ ++$count, $packet, $header, $user_data ]);
    };

    while (1) {
        my $retval;
        UNSAFE_SIGNALS {
            $retval = Net::Pcap::dispatch($pcap, 10, $callback, $user_data);
        };
        last unless ($retval);
        $Q->await($queue_limit) if ($queue_limit);
    }

    Net::Pcap::close($pcap);
}

sub consumer {
    my ($mce) = @_;
    my $wid = MCE->wid();

    while ( my $next = $Q->dequeue ) {
        my ($count, $packet, $header, $user_data) = @{ $next };
        my $output = '';

        $output .= sprintf "wid: %d, packet: %d, length: %d\n",
            $wid, $count, length $packet;

        for my $field (qw( len caplen tv_sec tv_usec )) {
            $output .= "field '$field' is present\n"
                if exists($header->{$field});
        }

        MCE->print($output);
    }
}

