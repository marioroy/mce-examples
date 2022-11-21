#!/usr/bin/env perl

## Usage: perl update3.pl

use strict;
use warnings;

use Cwd 'abs_path';

my ($prog_name, $prog_dir, $db_file);

BEGIN {
   $prog_name = $0;             $prog_name =~ s{^.*[\\/]}{}g;
   $prog_dir  = abs_path($0);   $prog_dir  =~ s{[\\/][^\\/]*$}{};
   $db_file   = "$prog_dir/SAMPLE.DB";
}

use MCE::Flow max_workers => 3, chunk_size => 300;

use Time::HiRes 'time';
use DBI;

my $start = time;

###############################################################################

sub db_iter_client_server {
   my ($dsn, $user, $password) = @_;

   my $dbh = DBI->connect($dsn, $user, $password, {
      PrintError => 0, RaiseError => 1, AutoCommit => 1,
      FetchHashKeyName => 'NAME_lc'
   }) or die $DBI::errstr;

   my $sth = $dbh->prepare(
      "SELECT seq_id, value1, value2 FROM seq"
   );
   $sth->execute;

   return sub {
      my ($chunk_size) = @_;
      if (my $rows_ref = $sth->fetchall_arrayref(undef, $chunk_size)) {
         return @{ $rows_ref };
      }
      return;
   };
}

sub db_iter_auto_offset {
   my ($dsn, $user, $password) = @_;

   my $dbh = DBI->connect($dsn, $user, $password, {
      PrintError => 0, RaiseError => 1, AutoCommit => 1,
      FetchHashKeyName => 'NAME_lc'
   }) or die $DBI::errstr;

   my $offset = 0; my $sth = $dbh->prepare(
      "SELECT seq_id, value1, value2 FROM seq LIMIT ? OFFSET ?"
   );

   return sub {
      my ($chunk_size) = @_;
      $sth->execute($chunk_size, $offset);
      if (my $rows_ref = $sth->fetchall_arrayref(undef, $chunk_size)) {
         $offset += $chunk_size;
         return @{ $rows_ref };
      }
      return;
   };
}

###############################################################################

my ($dsn, $user, $password) = ("dbi:SQLite:dbname=$db_file", "", "");

MCE::Flow::init {
   user_begin => sub {
      my ($mce, $task_id, $task_name) = @_;

      ## Store dbh and prepare statements inside the mce hash.

      $mce->{dbh} = DBI->connect($dsn, $user, $password, {
         PrintError => 0, RaiseError => 1, AutoCommit => 1,
         FetchHashKeyName => 'NAME_lc'
      }) or die $DBI::errstr;

      $mce->{dbh}->do('PRAGMA synchronous = OFF');
      $mce->{dbh}->do('PRAGMA journal_mode = MEMORY');

      $mce->{upd} = $mce->{dbh}->prepare(
         "UPDATE seq SET value1 = ?, value2 = ? WHERE seq_id = ?"
      );

      return;
   },
   user_end => sub {
      my ($mce, $task_id, $task_name) = @_;

      $mce->{upd}->finish;
      $mce->{dbh}->disconnect;

      return;
   }
};

mce_flow {
   input_data => db_iter_auto_offset($dsn, $user, $password)
},
sub {
   my ($mce, $chunk_ref, $chunk_id) = @_;
   my ($dbh, $upd) = ($mce->{dbh}, $mce->{upd});
   my $output = '';

   $dbh->begin_work;

   foreach my $row_ref (@{ $chunk_ref }) {
      my ($seq_id, $value1, $value2) = @{ $row_ref };
      $output .= "Updating row $seq_id\n";
      $upd->execute(int($value1 * 1.333), $value2 * 1.333, $seq_id);
   }

   MCE->print($output);

   $dbh->commit;
};

printf {*STDERR} "\n## Compute time: %0.03f\n\n", time - $start;

