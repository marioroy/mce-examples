#!/usr/bin/env perl

## Usage: perl query2.pl

use strict;
use warnings;

use Cwd 'abs_path';

my ($prog_name, $prog_dir, $db_file);

BEGIN {
   $prog_name = $0;             $prog_name =~ s{^.*[\\/]}{}g;
   $prog_dir  = abs_path($0);   $prog_dir  =~ s{[\\/][^\\/]*$}{};
   $db_file   = "$prog_dir/SAMPLE.DB";
}

use MCE::Loop max_workers => 3, chunk_size => 300;

use Time::HiRes 'time';
use DBI;

my $start = time;

###############################################################################

sub db_iter {
   my ($dsn, $user, $password) = @_;

   my $dbh = DBI->connect($dsn, $user, $password, {
      PrintError => 0, RaiseError => 1, AutoCommit => 1,
      FetchHashKeyName => 'NAME_lc'
   }) or die $DBI::errstr;

   my $sth = $dbh->prepare(
      "SELECT seq_id, value1, value2 FROM seq ORDER BY seq_id"
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

###############################################################################

my ($dsn, $user, $password) = ("dbi:SQLite:dbname=$db_file", "", "");

mce_loop {
   my ($mce, $chunk_ref, $chunk_id) = @_;
   my $output = '';

   foreach my $row_ref (@{ $chunk_ref }) {
      my ($seq_id, $value1, $value2) = @{ $row_ref };
      $output .= sprintf("%8ld %10ld %14.3lf\n", $seq_id, $value1, $value2);
   }

   MCE->print($output);

} db_iter($dsn, $user, $password);

printf {*STDERR} "\n## Compute time: %0.03f\n\n", time - $start;

