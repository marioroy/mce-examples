###############################################################################
## ----------------------------------------------------------------------------
## Throttle module for use with MCE::Shared.
##
###############################################################################

package Delay;

use 5.010001;
use strict;
use warnings;

use Time::HiRes "time";

sub new {
    my ($class, $delay) = @_;

    bless [ $delay // 0.1, time + ($delay // 0.1) ], $class;
}

sub get {
    my ($self) = @_;
    my ($time, $delay, $next) = (time, @{ $self });

    if ($time < $next) {
        $self->[1] += $delay;
        return $next - $time;
    }

    $self->[1] = $time + $delay;

    return 0;
}

1;

