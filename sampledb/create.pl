#!/usr/bin/env perl

## Usage: perl create.pl [ n_rows ]

use strict;
use warnings;

use Cwd 'abs_path';

my ($prog_name, $prog_dir, $db_file);

BEGIN {
   $prog_name = $0;             $prog_name =~ s{^.*[\\/]}{}g;
   $prog_dir  = abs_path($0);   $prog_dir  =~ s{[\\/][^\\/]*$}{};
   $db_file   = "$prog_dir/SAMPLE.DB";
}

use Time::HiRes 'time';
use DBI;

my $start = time;

###############################################################################
 
my $n_rows     = shift || 3000;
my $batch_size = 3000;
my $batch_i    = $batch_size;

unless ($n_rows =~ /\A\d+\z/) {
   die "usage: perl $prog_name [ n_rows ]\n";
}
if (-e $db_file) {
   unlink $db_file or die "Cannot unlink $db_file: $!\n";
}
 
my ($dsn, $user, $password) = ("dbi:SQLite:dbname=$db_file", "", "");

my $dbh = DBI->connect($dsn, $user, $password, {
   PrintError => 0, RaiseError => 1, AutoCommit => 1,
   FetchHashKeyName => 'NAME_lc',
}) or die $DBI::errstr;

exit($?) unless -e $db_file;

$dbh->do('PRAGMA page_size = 4096');

###############################################################################

my ($sql, $sth);

$sql = <<'END_SQL';
CREATE TABLE seq (
   seq_id   INTEGER PRIMARY KEY,
   value1   INTEGER,
   value2   REAL
)
END_SQL
 
$dbh->do($sql);

$sth = $dbh->prepare(
   "INSERT INTO seq (seq_id, value1, value2) VALUES (?, ?, ?)"
);

$dbh->begin_work;              ## $dbh->do('BEGIN');

for my $seq_id (1 .. $n_rows) {
   $sth->execute($seq_id, $seq_id * 2, $seq_id * 1.618);

   unless (--$batch_i) {
      $dbh->commit;            ## $dbh->do('COMMIT');
      $dbh->begin_work;        ## $dbh->do('BEGIN');
      $batch_i = $batch_size;
   }
}

$dbh->commit;                  ## $dbh->do('COMMIT');

$sth->finish;
$dbh->disconnect;

printf {*STDERR} "\n## Compute time: %0.03f\n\n", time - $start;

