###############################################################################
## ----------------------------------------------------------------------------
## Throttle module for use with MCE::Shared.
##
###############################################################################

package Delay;

use 5.010001;
use strict;
use warnings;

use Time::HiRes;

sub new {
    my ( $class, $delay ) = @_;

    bless [ $delay // 0.1, undef ], $class;
}

sub get {
    my ( $self ) = @_;
    my ( $delay, $time ) = ( $self->[0], Time::HiRes::time() );

    if ( !defined $self->[1] || $time >= $self->[1] ) {
        $self->[1] = $time + $delay;
        return $delay;
    }

    $self->[1] += $delay;

    return $self->[1] - $time;
}

1;

