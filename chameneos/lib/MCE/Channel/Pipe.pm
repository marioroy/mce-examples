###############################################################################
## ----------------------------------------------------------------------------
## Channel tuned for one producer and one consumer involving no locking.
##
###############################################################################

package MCE::Channel::Pipe;

use strict;
use warnings;

no warnings qw( uninitialized once );

our $VERSION = '1.902';

use base 'MCE::Channel';

my $LF = "\012"; Internals::SvREADONLY($LF, 1);
my $is_MSWin32 = ( $^O eq 'MSWin32' ) ? 1 : 0;
my $freeze     = MCE::Channel::_get_freeze();
my $thaw       = MCE::Channel::_get_thaw();

sub new {
   my ( $class, %obj ) = ( @_, impl => 'Pipe' );

   $obj{init_pid} = MCE::Channel::_pid();
   MCE::Util::_pipe_pair( \%obj, 'c_sock', 'p_sock' );

   return bless \%obj, $class;
}

###############################################################################
## ----------------------------------------------------------------------------
## Queue-like methods.
##
###############################################################################

sub end {
   my ( $self ) = @_;

   local $\ = undef if (defined $\);
   MCE::Util::_sock_ready_w( $self->{p_sock} ) if $is_MSWin32;
   print { $self->{p_sock} } pack('i', -1);

   $self->{ended} = 1;
}

sub enqueue {
   my $self = shift;
   return MCE::Channel::_ended('enqueue') if $self->{ended};

   local $\ = undef if (defined $\);
   MCE::Util::_sock_ready_w( $self->{p_sock} ) if $is_MSWin32;

   while ( @_ ) {
      my $data = $freeze->([ shift ]);
      print { $self->{p_sock} } pack('i', length $data) . $data;
   }

   return 1;
}

sub dequeue {
   my ( $self, $count ) = @_;
   $count = 1 if ( !$count || $count < 1 );

   local $/ = $LF if ( $/ ne $LF );

   if ( $count == 1 ) {
      my ( $plen, $data );
      MCE::Util::_sock_ready( $self->{c_sock} ) if $is_MSWin32;

      $is_MSWin32
         ? sysread( $self->{c_sock}, $plen, 4 )
         : read( $self->{c_sock}, $plen, 4 );

      my $len = unpack('i', $plen);
      if ( $len < 0 ) {
         $self->end;
         return wantarray ? () : undef;
      }

      $is_MSWin32
         ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
         : read( $self->{c_sock}, $data, $len );

      wantarray ? @{ $thaw->($data) } : ( $thaw->($data) )->[-1];
   }
   else {
      my ( $plen, @ret );
      MCE::Util::_sock_ready( $self->{c_sock} ) if $is_MSWin32;

      while ( $count-- ) {
         my $data;

         $is_MSWin32
            ? sysread( $self->{c_sock}, $plen, 4 )
            : read( $self->{c_sock}, $plen, 4 );

         my $len = unpack('i', $plen);
         if ( $len < 0 ) {
            $self->end;
            last;
         }

         $is_MSWin32
            ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
            : read( $self->{c_sock}, $data, $len );

         push @ret, @{ $thaw->($data) };
      }

      wantarray ? @ret : $ret[-1];
   }
}

sub dequeue_nb {
   my ( $self, $count ) = @_;
   $count = 1 if ( !$count || $count < 1 );

   my ( $plen, @ret );
   local $/ = $LF if ( $/ ne $LF );

   while ( $count-- ) {
      my $data;
      MCE::Util::_nonblocking( $self->{c_sock}, 1 );

      $is_MSWin32
         ? sysread( $self->{c_sock}, $plen, 4 )
         : read( $self->{c_sock}, $plen, 4 );

      MCE::Util::_nonblocking( $self->{c_sock}, 0 );

      my $len; $len = unpack('i', $plen) if $plen;
      if ( !$len || $len < 0 ) {
         $self->end if defined $len && $len < 0;
         last;
      }

      $is_MSWin32
         ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
         : read( $self->{c_sock}, $data, $len );

      push @ret, @{ $thaw->($data) };
   }

   wantarray ? @ret : $ret[-1];
}

###############################################################################
## ----------------------------------------------------------------------------
## Methods for one-way communication; producer(s) to consumers.
##
###############################################################################

sub send {
   my $self = shift;
   return MCE::Channel::_ended('send') if $self->{ended};

   my $data = $freeze->([ @_ ]);

   local $\ = undef if (defined $\);
   MCE::Util::_sock_ready_w( $self->{p_sock} ) if $is_MSWin32;
   print { $self->{p_sock} } pack('i', length $data) . $data;

   return 1;
}

sub recv {
   my ( $self ) = @_;
   my ( $plen, $data );

   local $/ = $LF if ( $/ ne $LF );
   MCE::Util::_sock_ready( $self->{c_sock} ) if $is_MSWin32;

   $is_MSWin32
      ? sysread( $self->{c_sock}, $plen, 4 )
      : read( $self->{c_sock}, $plen, 4 );

   my $len = unpack('i', $plen);
   if ( $len < 0 ) {
      $self->end;
      return wantarray ? () : undef;
   }

   $is_MSWin32
      ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
      : read( $self->{c_sock}, $data, $len );

   wantarray ? @{ $thaw->($data) } : ( $thaw->($data) )->[-1];
}

sub recv_nb {
   my ( $self ) = @_;
   my ( $plen, $data );

   local $/ = $LF if ( $/ ne $LF );
   MCE::Util::_nonblocking( $self->{c_sock}, 1 );

   $is_MSWin32
      ? sysread( $self->{c_sock}, $plen, 4 )
      : read( $self->{c_sock}, $plen, 4 );

   MCE::Util::_nonblocking( $self->{c_sock}, 0 );

   my $len; $len = unpack('i', $plen) if $plen;
   if ( !$len || $len < 0 ) {
      $self->end if defined $len && $len < 0;
      return wantarray ? () : undef;
   }

   $is_MSWin32
      ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
      : read( $self->{c_sock}, $data, $len );

   wantarray ? @{ $thaw->($data) } : ( $thaw->($data) )->[-1];
}

1;

__END__

###############################################################################
## ----------------------------------------------------------------------------
## Module usage.
##
###############################################################################

=head1 NAME

MCE::Channel::Pipe - Channel tuned for one producer and one consumer

=head1 VERSION

This document describes MCE::Channel::Pipe version 1.902

=head1 DESCRIPTION

A channel class providing queue-like one-way communication
for one process or thread; no locking needed.

The API is described in L<MCE::Channel>. This lacks two-way
support i.e. C<send2>, C<recv2>, and C<recv2_nb>.

Current module available since MCE 1.902.

=over 3

=item new

 use MCE::Channel;

 my $chnl = MCE::Channel->new( impl => 'Pipe' );

=back

=head1 QUEUE-LIKE BEHAVIOR

=over 3

=item enqueue

=item dequeue

=item dequeue_nb

=item end

=back

=head1 ONE-WAY IPC - PRODUCER TO CONSUMER

=over 3

=item send

=item recv

=item recv_nb

=back

=head1 AUTHOR

Mario E. Roy, S<E<lt>marioeroy AT gmail DOT comE<gt>>

=cut

