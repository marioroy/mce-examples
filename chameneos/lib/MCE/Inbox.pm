###############################################################################
## ----------------------------------------------------------------------------
## Channel-like messaging supporting threads and processes.
##
###############################################################################

package MCE::Inbox;

use strict;
use warnings;

our $VERSION = '0.001';

## no critic (BuiltinFunctions::ProhibitStringyEval)

use if  $INC{'threads.pm'}, 'threads::shared';
use if  $INC{'threads.pm'}, 'Thread::Queue';
use if !$INC{'threads.pm'}, 'MCE::Shared';

# If available, use Sereal for serialization (faster).

my ( $has_threads, $freeze, $thaw );

BEGIN {
   $has_threads = $INC{'threads.pm'} ? 1 : 0;
   local $@; eval '
      use Sereal::Encoder 3.015 qw( encode_sereal );
      use Sereal::Decoder 3.015 qw( decode_sereal );
   ';
   if ( !$@ ) {
      my $encoder_ver = int( Sereal::Encoder->VERSION() );
      my $decoder_ver = int( Sereal::Decoder->VERSION() );
      if ( $encoder_ver - $decoder_ver == 0 ) {
         $freeze = \&encode_sereal;
         $thaw   = \&decode_sereal;
      }
   }
   if ( !defined $freeze ) {
      require Storable;
      $freeze = \&Storable::freeze;
      $thaw   = \&Storable::thaw;
   }
}

# $inbox = MCE::Inbox->new( @ids );

sub new {
   local $_; my ( $class, @ids ) = @_;

   my %self = ( $has_threads )
      ? map { $_ => Thread::Queue->new() } @ids
      : map { $_ => MCE::Shared->queue( await => 1 ) } @ids;

   MCE::Shared->start() if (!$has_threads && !$INC{'IO/FDPass.pm'});
   $self{_LIMIT_} = {};

   bless \%self, $class;
}

# $inbox->limit( $id, $size );
# $inbox->limit( \@list, $size );

sub limit {
   my ( $self, $id, $size ) = @_;

   for my $_id ( ref $id eq 'ARRAY' ? @{ $id } : $id ) {
      next unless exists $self->{$_id};
      if ( $has_threads ) {
         $self->{$_id}->limit = $size;
      } else {
         $self->{_LIMIT_}{$_id} = $size;
      }
   }

   return 1;
}

# @data = $inbox->recv( $id );
# $mesg = $inbox->recv( $id );

sub recv {
   my ( $self, $id ) = @_;
   return () unless exists $self->{$id};
   my $data = $self->{$id}->dequeue();

   ( wantarray )
    ? $data ? @{ $thaw->($data) } : ()
    : $data ? ($thaw->($data))->[-1] : undef;
}

# @data = $inbox->recv_nb( $id );
# $mesg = $inbox->recv_nb( $id );

sub recv_nb {
   my ( $self, $id ) = @_;
   return () unless exists $self->{$id};
   my $data = $self->{$id}->dequeue_nb();

   ( wantarray )
    ? $data ? @{ $thaw->($data) } : ()
    : $data ? ($thaw->($data))->[-1] : undef;
}

# $inbox->send( $id, @data );
# $inbox->send( \@list, @data );

sub send {
   my ( $self, $id ) = ( shift, shift );
   my $data = $freeze->([ @_ ]);

   if ( scalar keys %{ $self->{_LIMIT_} } ) {
      for my $_id ( ref $id eq 'ARRAY' ? @{ $id } : $id ) {
         next unless exists $self->{$_id};
         $self->{$_id}->await($self->{_LIMIT_}{$_id})
            if ( defined $self->{_LIMIT_}{$_id} );

         $self->{$_id}->enqueue($data);
      }
   }
   else {
      for my $_id ( ref $id eq 'ARRAY' ? @{ $id } : $id ) {
         next unless exists $self->{$_id};
         $self->{$_id}->enqueue($data);
      }
   }

   return 1;
}

# $scalar = $inbox->size( [ $id ] );
# %pairs  = $inbox->size();

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

# $inbox->end( [ $id ] );

sub end {
   my ( $self, $id ) = @_;

   if ( defined $id ) {
      exists $self->{$id} ? $self->{$id}->end() : return undef;
   } else {
      for my $_id ( grep { $_ ne '_LIMIT_' } keys %{ $self } ) {
         $self->{$_id}->end();
      }
   }

   return 1;
}

1;

