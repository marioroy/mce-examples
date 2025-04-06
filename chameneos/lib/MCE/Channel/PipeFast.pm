###############################################################################
## ----------------------------------------------------------------------------
## Channel tuned for one producer and one consumer involving no locking.
##
###############################################################################

package MCE::Channel::PipeFast;

use strict;
use warnings;

no warnings qw( uninitialized once );

our $VERSION = '1.902';

use base 'MCE::Channel';

my $LF = "\012"; Internals::SvREADONLY($LF, 1);
my $is_MSWin32 = ( $^O eq 'MSWin32' ) ? 1 : 0;

sub new {
   my ( $class, %obj ) = ( @_, impl => 'PipeFast' );

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
      my $data = ''.shift;
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

      return '' unless $len;
      $is_MSWin32
         ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
         : read( $self->{c_sock}, $data, $len );

      $data;
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

         push(@ret, ''), next unless $len;
         $is_MSWin32
            ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
            : read( $self->{c_sock}, $data, $len );

         push @ret, $data;
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
         $self->end    if defined $len && $len < 0;
         push @ret, '' if defined $len && $len == 0;
         last;
      }

      $is_MSWin32
         ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
         : read( $self->{c_sock}, $data, $len );

      push @ret, $data;
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

   my $data = ''.shift;

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

   return '' unless $len;

   $is_MSWin32
      ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
      : read( $self->{c_sock}, $data, $len );

   $data;
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
      return ''  if defined $len && $len == 0;
      return wantarray ? () : undef;
   }

   $is_MSWin32
      ? MCE::Channel::_read( $self->{c_sock}, $data, $len )
      : read( $self->{c_sock}, $data, $len );

   $data;
}

1;

__END__

###############################################################################
## ----------------------------------------------------------------------------
## Module usage.
##
###############################################################################

=head1 NAME

MCE::Channel::PipeFast - Fast channel tuned for one producer and one consumer

=head1 VERSION

This document describes MCE::Channel::PipeFast version 1.902

=head1 DESCRIPTION

A channel class providing queue-like one-way communication
for one process or thread; no locking needed.

This is similar to L<MCE::Channel::Pipe> but optimized for
non-Unicode strings only. The main difference is that this module
lacks freeze-thaw serialization. Non-string arguments become
stringified; i.e. numbers and undef.

The API is described in L<MCE::Channel> with the sole difference
being C<send> handles one argument. This lacks two-way support
i.e. C<send2>, C<recv2>, and C<recv2_nb>.

Current module available since MCE 1.902.

=over 3

=item new

 use MCE::Channel;

 my $chnl = MCE::Channel->new( impl => 'PipeFast' );

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

