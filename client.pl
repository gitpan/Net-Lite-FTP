#!/usr/bin/perl -w

use lib "./lib/";
use Net::Lite::FTP;
my $tlsftp=Net::Lite::FTP->new();
$tlsftp->open("ftp.tls.com","21");
$tlsftp->user("user");
$tlsftp->pass("password");
#$tlsftp->command("PWD");
$tlsftp->command( "PBSZ 0");
$tlsftp->command("PROT P");
$tlsftp->nlist();
$tlsftp->cwd("pub");
my @files=$tlsftp->nlist("*.exe");
use Data::Dumper;
foreach $f (@files) {
 print "Hello world\n$f\n";
 print Dumper($f);
};

