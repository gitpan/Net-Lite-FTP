#!/usr/bin/perl -w

use lib "./lib/";
use Net::Lite::FTP;
my $tlsftp=Net::Lite::FTP->new();
$tlsftp->open("ftp.ebi.pl","21");
$tlsftp->user("al_test");
$tlsftp->pass("12345678");
#$tlsftp->command("PWD");
$tlsftp->command( "PBSZ 0");
$tlsftp->command("PROT P");
$tlsftp->nlist();
$tlsftp->cwd("arm");
my @files=$tlsftp->nlist("*.exe");
use Data::Dumper;
foreach $f (@files) {
 print "Hello world\n$f\n";
 print Dumper($f);
};

