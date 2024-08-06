#!/usr/bin/env perl

# Many ellipses demonstration using Graphics::Framebuffer and threads.

use strict;

use Graphics::Framebuffer;
use Time::HiRes qw( sleep time );
use Getopt::Long;
use Pod::Usage;
use List::Util qw( max min );

use threads stack_size => 131072;
use MCE::Shared 1.864; # minimum version required

package App::Framebuffer {
    use base 'Graphics::Framebuffer';

    sub ellipse2 {
        my ( $self, $r, $g, $b, $p ) = @_;
        $self->set_color({ red => $r, green => $g, blue => $b });

        my $cx = ( $p->{xx} > $p->{x} ) ? $p->{x} : $p->{xx};
        my $cy = ( $p->{yy} > $p->{y} ) ? $p->{y} : $p->{yy};

        my $xradius = abs( $p->{xx} - $p->{x} ) >> 1;
        my $yradius = abs( $p->{yy} - $p->{y} ) >> 1;

        $self->ellipse({
            x => $cx + $xradius, xradius => $xradius,
            y => $cy + $yradius, yradius => $yradius,
        });

        $self->vsync();
    }
};

my $dev      = 0;
my $delay    = 0.050;
my $nitems   = 25;
my $noerase  = 0;
my $nworkers = 2;
my $runmode  = 0;
my $sharedfb = 0;
my $help     = 0;

GetOptions(
    'dev=i'      => \$dev,
    'delay=f'    => \$delay,
    'nitems=i'   => \$nitems,
    'noerase'    => \$noerase,
    'nworkers=i' => \$nworkers,
    'runmode=i'  => \$runmode,
    'sharedfb'   => \$sharedfb,
    'help'       => \$help,
);

pod2usage('-exitstatus' => 1, '-verbose' => $help) if $help;

$delay    = max(0, min( 10, $delay   ));
$nitems   = max(2, min(999, $nitems  ));
$nworkers = max(1, min( 20, $nworkers));
$runmode  = max(0, min(  4, $runmode ));

# Construct a shared framebuffer (resides under the shared-manager process).
# The shared-object is accessible via the OO interface only.

my $F = MCE::Shared->share( { module => 'App::Framebuffer' },
    'FB_DEVICE'   => "/dev/fb$dev",
    'ACCELERATED' => 1,
    'SHOW_ERRORS' => 0,
    'SPLASH'      => 0,
    'RESET'       => FALSE
);

$F->cls('OFF');

use constant { NUMCOLORS => 96, DELTA => 9, OFFSET => 5 };
use constant { X1 => 0, Y1 => 1, X2 => 2, Y2 => 3 };

my ( $x1, $y1, $x2, $y2, $dx1, $dy1, $dx2, $dy2 );
my ( $i, $j, $k, @b, @c, @red, @green, @blue );
my ( $t, $d );

my $screen_info   = $F->screen_dimensions();
my $screen_width  = $screen_info->{width};
my $screen_height = $screen_info->{height};

my $done = MCE::Shared->scalar( FALSE );

$SIG{INT} = $SIG{TERM} = sub {
    return MCE::Signal::defer($_[0]) if $MCE::Signal::IPC;
    $done->set( TRUE );
};

# press ctrl-c to stop the script
# must also stop the shared-manager before exec

for ( 1 .. $nworkers ) {
    last if $done->get();
    threads->create( \&loop, $_, $dev )
}

# joining threads blocks signals, so do this
sleep 0.1 until $done->get();

$_->join() for threads->list();
MCE::Shared->stop();

exec('reset');

sub loop {
    my ( $id, $dev ) = @_;

    unless ( $sharedfb ) {
        $F = App::Framebuffer->new(
            'FB_DEVICE'   => "/dev/fb$dev",
            'ACCELERATED' => 1,
            'SHOW_ERRORS' => 0,
            'SPLASH'      => 0,
            'RESET'       => FALSE
        );
    }

    initColors();
    initBuffers();

    while ( ! $done->get() ) {
        $t = time if $delay;

        # Erase old
        unless ( $noerase ) {
            $j = ( $j + 1 ) % $nitems;
            draw( int(0), int(0), int(0), $j );
        }

        # Get next coordinates
        getNextCoordinates( $screen_width,  \$x1, \$dx1 );
        getNextCoordinates( $screen_height, \$y1, \$dy1 );
        getNextCoordinates( $screen_width,  \$x2, \$dx2 );
        getNextCoordinates( $screen_height, \$y2, \$dy2 );

        # Get next pen color
        $k = ( $k + 1 ) % NUMCOLORS;

        $b[$i][X1] = int($x1), $c[$i][X1] = int( $screen_width  - $x1 - 1 );
        $b[$i][Y1] = int($y1), $c[$i][Y1] = int( $screen_height - $y1 - 1 );
        $b[$i][X2] = int($x2), $c[$i][X2] = int( $screen_width  - $x2 - 1 );
        $b[$i][Y2] = int($y2), $c[$i][Y2] = int( $screen_height - $y2 - 1 );

        # Draw new
        draw( $red[$k], $green[$k], $blue[$k], $i );

        $i = ( $i + 1 ) % $nitems;

        if ( $delay ) {
            $d = $delay - (time - $t);
            sleep($d) if $d > 0.0;
        }
    }

    return;
}

sub draw {
    my ( $r, $g, $b, $index ) = @_;

    $F->ellipse2( $r, $g, $b, {
        x  => $b[$index][X1], y  => $b[$index][Y1],
        xx => $b[$index][X2], yy => $b[$index][Y2],
    });
    if ( $runmode == 1 || $runmode == 4 ) {
        $F->ellipse2( $r, $g, $b, {
            x  => $c[$index][X1], y  => $c[$index][Y1],
            xx => $c[$index][X2], yy => $c[$index][Y2],
        });
    }
    if ( $runmode == 2 || $runmode == 4 ) {
        $F->ellipse2( $r, $g, $b, {
            x  => $b[$index][X1], y  => $c[$index][Y1],
            xx => $b[$index][X2], yy => $c[$index][Y2],
        });
    }
    if ( $runmode == 3 || $runmode == 4 ) {
        $F->ellipse2( $r, $g, $b, {
            x  => $c[$index][X1], y  => $b[$index][Y1],
            xx => $c[$index][X2], yy => $b[$index][Y2],
        });
    }
}

sub newColor {
    int( rand NUMCOLORS );
}

sub velocityPlus {
    int( rand DELTA ) + OFFSET;
}

sub velocityMinus {
   -int( rand DELTA ) - OFFSET;
}

sub getNextCoordinates {
    my ( $max, $pn, $pdn ) = @_;

    $$pn += $$pdn;    # move (n) by velocity factor

    if ( $$pn <= 0 + 1 ) {
        $$pn -= $$pdn;
        $$pn += ( $$pdn = velocityPlus() );
    }
    elsif ( $$pn >= $max - 1 ) {
        $$pn -= $$pdn;
        $$pn += ( $$pdn = velocityMinus() );
    }
}

sub getStartingCoordinates {
    my ( $max, $n1, $n2 ) = @_;
    my $temp;

    do {
        $$n1  = int( rand $max );
        $$n2  = int( rand $max );
        $temp = abs( $$n2 - $$n1 );
    } while ( $temp < 16 || $temp > 64 );
}

sub initBuffers {
    for my $i ( 0 .. $nitems - 1 ) {
        $b[$i][X1] = $b[$i][Y1] = $b[$i][X2] = $b[$i][Y2] = int(0);
        $c[$i][X1] = $c[$i][Y1] = $c[$i][X2] = $c[$i][Y2] = int(0);
    }

    $i = $j = 0, $k = newColor();

    getStartingCoordinates( $screen_width,  \$x1, \$x2 );
    getStartingCoordinates( $screen_height, \$y1, \$y2 );

    if ( int rand(2) ) {
        $dx1 = velocityPlus(),  $dy1 = velocityPlus();
        $dx2 = velocityPlus(),  $dy2 = velocityPlus();
    } else {
        $dx1 = velocityMinus(), $dy1 = velocityMinus();
        $dx2 = velocityMinus(), $dy2 = velocityMinus();
    }
}

sub initColors {
    # pre-allocate the RGB arrays
    $#red   = NUMCOLORS - 1;
    $#green = NUMCOLORS - 1;
    $#blue  = NUMCOLORS - 1;

    # init in the event one were to change the constant above
    for ( 0 .. NUMCOLORS - 1 ) {
        $red[$_] = $green[$_] = $blue[$_] = int(0);
    }

    # fill in the color tables (96 rows) with preset values
    $red[ 0] = int(255);   $green[ 0] = int(  0);   $blue[ 0] = int(  0);
    $red[ 1] = int(255);   $green[ 1] = int( 15);   $blue[ 1] = int(  0);
    $red[ 2] = int(255);   $green[ 2] = int( 31);   $blue[ 2] = int(  0);
    $red[ 3] = int(255);   $green[ 3] = int( 47);   $blue[ 3] = int(  0);
    $red[ 4] = int(255);   $green[ 4] = int( 63);   $blue[ 4] = int(  0);
    $red[ 5] = int(255);   $green[ 5] = int( 79);   $blue[ 5] = int(  0);
    $red[ 6] = int(255);   $green[ 6] = int( 95);   $blue[ 6] = int(  0);
    $red[ 7] = int(255);   $green[ 7] = int(111);   $blue[ 7] = int(  0);
    $red[ 8] = int(255);   $green[ 8] = int(127);   $blue[ 8] = int(  0);
    $red[ 9] = int(255);   $green[ 9] = int(143);   $blue[ 9] = int(  0);
    $red[10] = int(255);   $green[10] = int(159);   $blue[10] = int(  0);
    $red[11] = int(255);   $green[11] = int(175);   $blue[11] = int(  0);
    $red[12] = int(255);   $green[12] = int(191);   $blue[12] = int(  0);
    $red[13] = int(255);   $green[13] = int(207);   $blue[13] = int(  0);
    $red[14] = int(255);   $green[14] = int(223);   $blue[14] = int(  0);
    $red[15] = int(255);   $green[15] = int(239);   $blue[15] = int(  0);
    $red[16] = int(255);   $green[16] = int(255);   $blue[16] = int(  0);
    $red[17] = int(239);   $green[17] = int(255);   $blue[17] = int(  0);
    $red[18] = int(223);   $green[18] = int(255);   $blue[18] = int(  0);
    $red[19] = int(207);   $green[19] = int(255);   $blue[19] = int(  0);
    $red[20] = int(191);   $green[20] = int(255);   $blue[20] = int(  0);
    $red[21] = int(175);   $green[21] = int(255);   $blue[21] = int(  0);
    $red[22] = int(159);   $green[22] = int(255);   $blue[22] = int(  0);
    $red[23] = int(143);   $green[23] = int(255);   $blue[23] = int(  0);
    $red[24] = int(127);   $green[24] = int(255);   $blue[24] = int(  0);
    $red[25] = int(111);   $green[25] = int(255);   $blue[25] = int(  0);
    $red[26] = int( 95);   $green[26] = int(255);   $blue[26] = int(  0);
    $red[27] = int( 79);   $green[27] = int(255);   $blue[27] = int(  0);
    $red[28] = int( 63);   $green[28] = int(255);   $blue[28] = int(  0);
    $red[29] = int( 47);   $green[29] = int(255);   $blue[29] = int(  0);
    $red[30] = int( 31);   $green[30] = int(255);   $blue[30] = int(  0);
    $red[31] = int( 15);   $green[31] = int(255);   $blue[31] = int(  0);
    $red[32] = int(  0);   $green[32] = int(255);   $blue[32] = int(  0);
    $red[33] = int(  0);   $green[33] = int(255);   $blue[33] = int( 15);
    $red[34] = int(  0);   $green[34] = int(255);   $blue[34] = int( 31);
    $red[35] = int(  0);   $green[35] = int(255);   $blue[35] = int( 47);
    $red[36] = int(  0);   $green[36] = int(255);   $blue[36] = int( 63);
    $red[37] = int(  0);   $green[37] = int(255);   $blue[37] = int( 79);
    $red[38] = int(  0);   $green[38] = int(255);   $blue[38] = int( 95);
    $red[39] = int(  0);   $green[39] = int(255);   $blue[39] = int(111);
    $red[40] = int(  0);   $green[40] = int(255);   $blue[40] = int(127);
    $red[41] = int(  0);   $green[41] = int(255);   $blue[41] = int(143);
    $red[42] = int(  0);   $green[42] = int(255);   $blue[42] = int(159);
    $red[43] = int(  0);   $green[43] = int(255);   $blue[43] = int(175);
    $red[44] = int(  0);   $green[44] = int(255);   $blue[44] = int(191);
    $red[45] = int(  0);   $green[45] = int(255);   $blue[45] = int(207);
    $red[46] = int(  0);   $green[46] = int(255);   $blue[46] = int(223);
    $red[47] = int(  0);   $green[47] = int(255);   $blue[47] = int(239);
    $red[48] = int(  0);   $green[48] = int(255);   $blue[48] = int(255);
    $red[49] = int(  0);   $green[49] = int(239);   $blue[49] = int(255);
    $red[50] = int(  0);   $green[50] = int(223);   $blue[50] = int(255);
    $red[51] = int(  0);   $green[51] = int(207);   $blue[51] = int(255);
    $red[52] = int(  0);   $green[52] = int(191);   $blue[52] = int(255);
    $red[53] = int(  0);   $green[53] = int(175);   $blue[53] = int(255);
    $red[54] = int(  0);   $green[54] = int(159);   $blue[54] = int(255);
    $red[55] = int(  0);   $green[55] = int(143);   $blue[55] = int(255);
    $red[56] = int(  0);   $green[56] = int(127);   $blue[56] = int(255);
    $red[57] = int(  0);   $green[57] = int(111);   $blue[57] = int(255);
    $red[58] = int(  0);   $green[58] = int( 95);   $blue[58] = int(255);
    $red[59] = int(  0);   $green[59] = int( 79);   $blue[59] = int(255);
    $red[60] = int(  0);   $green[60] = int( 63);   $blue[60] = int(255);
    $red[61] = int(  0);   $green[61] = int( 47);   $blue[61] = int(255);
    $red[62] = int(  0);   $green[62] = int( 31);   $blue[62] = int(255);
    $red[63] = int(  0);   $green[63] = int( 15);   $blue[63] = int(255);
    $red[64] = int(  0);   $green[64] = int(  0);   $blue[64] = int(255);
    $red[65] = int( 15);   $green[65] = int(  0);   $blue[65] = int(255);
    $red[66] = int( 31);   $green[66] = int(  0);   $blue[66] = int(255);
    $red[67] = int( 47);   $green[67] = int(  0);   $blue[67] = int(255);
    $red[68] = int( 63);   $green[68] = int(  0);   $blue[68] = int(255);
    $red[69] = int( 79);   $green[69] = int(  0);   $blue[69] = int(255);
    $red[70] = int( 95);   $green[70] = int(  0);   $blue[70] = int(255);
    $red[71] = int(111);   $green[71] = int(  0);   $blue[71] = int(255);
    $red[72] = int(127);   $green[72] = int(  0);   $blue[72] = int(255);
    $red[73] = int(143);   $green[73] = int(  0);   $blue[73] = int(255);
    $red[74] = int(159);   $green[74] = int(  0);   $blue[74] = int(255);
    $red[75] = int(175);   $green[75] = int(  0);   $blue[75] = int(255);
    $red[76] = int(191);   $green[76] = int(  0);   $blue[76] = int(255);
    $red[77] = int(207);   $green[77] = int(  0);   $blue[77] = int(255);
    $red[78] = int(223);   $green[78] = int(  0);   $blue[78] = int(255);
    $red[79] = int(239);   $green[79] = int(  0);   $blue[79] = int(255);
    $red[80] = int(255);   $green[80] = int(  0);   $blue[80] = int(255);
    $red[81] = int(255);   $green[81] = int(  0);   $blue[81] = int(239);
    $red[82] = int(255);   $green[82] = int(  0);   $blue[82] = int(223);
    $red[83] = int(255);   $green[83] = int(  0);   $blue[83] = int(207);
    $red[84] = int(255);   $green[84] = int(  0);   $blue[84] = int(191);
    $red[85] = int(255);   $green[85] = int(  0);   $blue[85] = int(175);
    $red[86] = int(255);   $green[86] = int(  0);   $blue[86] = int(159);
    $red[87] = int(255);   $green[87] = int(  0);   $blue[87] = int(143);
    $red[88] = int(255);   $green[88] = int(  0);   $blue[88] = int(127);
    $red[89] = int(255);   $green[89] = int(  0);   $blue[89] = int(111);
    $red[90] = int(255);   $green[90] = int(  0);   $blue[90] = int( 95);
    $red[91] = int(255);   $green[91] = int(  0);   $blue[91] = int( 79);
    $red[92] = int(255);   $green[92] = int(  0);   $blue[92] = int( 63);
    $red[93] = int(255);   $green[93] = int(  0);   $blue[93] = int( 47);
    $red[94] = int(255);   $green[94] = int(  0);   $blue[94] = int( 31);
    $red[95] = int(255);   $green[95] = int(  0);   $blue[95] = int( 15);
}

__END__

=pod

=head1 NAME

Ellipse Demo

=head1 DESCRIPTION

Many ellipses demonstration using Graphics::Framebuffer and threads.

=head1 SYNOPSIS

 perl many_ellipses.pl [options]

 Press Ctrl-C to stop the demo.

=head2 OPTIONS

=over 2

=item B<-sharedfb>

Have workers use the shared-framebuffer instead.

=item B<-delay>=fraction

The number of seconds to pause between iterations.

Default is 0.010 seconds.

=item B<-nitems>=2-999

The number of ellipses per set; default 50.

=item B<-noerase>

Keep older ellipses on the screen.

=item B<-nworkers>=1-20

The number of workers to run; default 2.

=item B<-runmode>=0-4

The run-time effect; default 1.

 0 = Single
 1 = Diagonal
 2 = Horizontal
 3 = Vertical
 4 = Quadrupal

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2019 by Mario E. Roy

This demo is released under the same license as Perl.

See L<https://dev.perl.org/licenses/> for more information.

=cut

