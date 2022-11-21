###############################################################################
## ----------------------------------------------------------------------------
## Channel-like messaging supporting threads and processes.
##
###############################################################################

package MCE::Inbox;

use strict;
use warnings;

our $VERSION = '0.002';

use MCE::Shared 1.841;

my $freeze = MCE::Shared::Server::_get_freeze();
my $thaw   = MCE::Shared::Server::_get_thaw();

# $inbox = MCE::Inbox->new( @ids )

sub new {
   my ( $class, @ids ) = @_;
   my %self = map { $_ => MCE::Shared->queue( await => 1, barrier => 0 ) } @ids;

   MCE::Shared->start() unless $INC{'IO/FDPass.pm'};
   $self{_LIMIT_} = {};

   bless \%self, $class;
}

# $inbox->limit( $id, $size )
# $inbox->limit( \@list, $size )

sub limit {
   my ( $self, $id, $size ) = @_;
   my $ret = 1;

   for my $_id ( ref($id) eq 'ARRAY' ? @{ $id } : $id ) {
      $ret = undef, next unless exists $self->{$_id};
      $self->{_LIMIT_}{$_id} = $size;
   }

   return $ret;
}

# @data = $inbox->recv( $id )
# $mesg = $inbox->recv( $id )

sub recv {
   my ( $self, $id ) = @_;
   return () unless exists $self->{$id};
   my $data = $self->{$id}->dequeue();

   wantarray
      ? $data ? @{ $thaw->($data) } : ()
      : $data ? ($thaw->($data))->[-1] : undef;
}

# @data = $inbox->recv_nb( $id )
# $mesg = $inbox->recv_nb( $id )

sub recv_nb {
   my ( $self, $id ) = @_;
   return () unless exists $self->{$id};
   my $data = $self->{$id}->dequeue_nb();

   wantarray
      ? $data ? @{ $thaw->($data) } : ()
      : $data ? ($thaw->($data))->[-1] : undef;
}

# $inbox->send( $id, @data )
# $inbox->send( \@list, @data )

sub send {
   my ( $self, $id ) = ( shift, shift );
   my $data = $freeze->([ @_ ]);
   my $ret  = 1;

   if ( scalar keys %{ $self->{_LIMIT_} } ) {
      for my $_id ( ref($id) eq 'ARRAY' ? @{ $id } : $id ) {
         $ret = undef, next unless exists $self->{$_id};

         $self->{$_id}->await($self->{_LIMIT_}{$_id})
            if ( defined $self->{_LIMIT_}{$_id} );

         $self->{$_id}->enqueue($data);
      }
   }
   else {
      for my $_id ( ref($id) eq 'ARRAY' ? @{ $id } : $id ) {
         $ret = undef, next unless exists $self->{$_id};
         $self->{$_id}->enqueue($data);
      }
   }

   return $ret;
}

# $count = $inbox->size( $id )
# %pairs = $inbox->size( )

sub size {
   local $_; my ( $self, $id ) = @_;

   if ( defined $id ) {
      exists $self->{$id} ? $self->{$id}->pending() : undef;
   }
   elsif ( wantarray ) {
      map { $_ => $self->{$_}->pending() }
         grep { $_ ne '_LIMIT_' } keys %{ $self };
   }
   else {
      my $size = 0;
      for my $_id ( grep { $_ ne '_LIMIT_' } keys %{ $self } ) {
         $size += $self->{$_id}->pending();
      }
      $size;
   }
}

# $inbox->end( $id )
# $inbox->end( \@list )
# $inbox->end( )

sub end {
   my ( $self, $id ) = @_;
   my $ret = 1;

   if ( defined $id ) {
      for my $_id ( ref($id) eq 'ARRAY' ? @{ $id } : $id ) {
         $ret = undef, next unless exists $self->{$_id};
         $self->{$_id}->end();
      }
   }
   else {
      for my $_id ( grep { $_ ne '_LIMIT_' } keys %{ $self } ) {
         $self->{$_id}->end();
      }
   }

   return $ret;
}

1;

