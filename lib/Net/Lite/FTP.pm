package Net::Lite::FTP;

use 5.008004;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Net::Lite::FTP ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.11';
# Preloaded methods go here.
# Autoload methods go after =cut, and are processed by the autosplit program.
use constant BUFSIZE => 4096;
BEGIN {
use Net::SSLeay::Handle qw/shutdown/;
# You only need this if your FTP server requires client certs:
#Net::SSLeay::Handle::_set_cert("/home/eyck/my.pem"); 
#Net::SSLeay::Handle::_set_key("/home/eyck/my.pem");
# but if you want this, you need to patch you Net::SSLeay, 
};

sub new($$) {
    my $class=shift;
    my $self={};
    bless $self,$class;
#                            $self->{'DBHandle'}=$dbh;
    $self->{"CreationTime"}=time;
    $self->{"Connected"}=0;
    $self->{"EncryptData"}=1;
    $self->{"Debug"}=1;
    return $self;
};

sub user($$) {
	my ($self,$user)=@_;
	$self->command("USER $user");
}
sub pass($$) {
	my ($self,$user)=@_;
	$self->command("PASS $user");
}
sub cwd ($$) {
    my ($self,$data)=@_;
    $self->command("CWD $data");
}


sub open($$$) {
   my ($self,$host,$port)=@_;
   my ($data);
   my $sock;
   $sock = Net::SSLeay::Handle->make_socket($host, $port);
   if (sysread($sock,$data,BUFSIZE)) {
	   print STDERR "Received: $data" if $self->{Debug};
   }
    $data="AUTH TLS\n";
    syswrite($sock,$data);
    if (sysread($sock,$data,BUFSIZE)) {
        print STDERR "Received: $data" if $self->{Debug};
    }
    $self->{'RAWSock'}=$sock;

    {tie(*S, "Net::SSLeay::Handle", $sock);$sock = \*S;};
    $self->{'Sock'}=$sock;
    {select($sock);$|=1;select(STDOUT);};#unbuffer socket
    # 
    $self->command("PBSZ 0");# TODO
    $self->command("PROT P");# WARNING: Hardcoded values...
    return 1;
}
sub command ($$){
    my ($self,$data)=@_;
    print STDERR "Sending: ",$data."\n" if $self->{Debug};
    my $sock=$self->{'Sock'};
    print $sock $data."\n";
    return $self->response();
}

sub response ($) {
    my ($self)=@_;
    my $sock=$self->{'Sock'};
    my ($read,$resp,$code,$cont);
    $read=($resp=<$sock>);
    return unless defined($read);
    #UWAGA!
    # wcale nieprawda to co nizej pisze. Jesli pierwsza linijka to \d\d\d-
    #  to odbierac linijki az do napotkania \d\d\d\s
    #  np:
    #  226-EDI processing started
    #   01 costam...
    #   02 costam..
    #  226 ...EDI processing complete

    
    # Responsy maja format \d\d\d
    #  lub wielolinijkowe: \d\d\d-
    print STDERR "SRV Response: $read" if $self->{Debug};
    $read=~/^(\d\d\d)/  && do {
        $code=$1;
    };
    $read=~/^(\d\d\d)-/  && do {
        $cont=1;
    };
    if ($cont) {
        do {
            $read=<$sock>;
            $resp.=$read;
            print " ----> $read\n" if $self->{Debug};
        } until ($read=~/^\d\d\d\s/);
    };

    if ($code>399) {
        warn "Jaki¶ problem, chyba najlepiej sie wycofac\n";
        warn $resp;
        print "ERR: $resp\n";
        die "Server said we're bad.";
    };
    print STDERR "RECV: ",$resp if $self->{Debug};
    return $resp;
}

sub list {return nlst(@_);};
sub nlst {
    my ($self,$mask)=@_;
    my $sock=$self->{'Sock'};
    my $socket;
    my (@files);
    my $tmp;
    $tmp=$self->command("PASV");
    $tmp=~/227 [^\d]*(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)/ && do {
        #print "I przyszlo $1 $2 $3 $4 $5 $6, port ",$5*256+$6,"\n";
        my $port=$5*256+$6;
        my $host="$1.$2.$3.$4";
        #print " $host : $port \n";
        $socket = Net::SSLeay::Handle->make_socket($host, $port);
        print STDERR "Data link connected.. to $host at $port\n" if $self->{Debug};
    };
    if (defined($mask)) {
        $self->command("NLST $mask");
    } else {
        $self->command("NLST");
    };

    tie(*S1, "Net::SSLeay::Handle", $socket);
    print STDERR "SSL for data connection enabled...\n" if $self->{Debug};
    $socket = \*S1;
    while ($tmp=<$socket>) {
	    #print STDERR "G: $q";
	    chop($tmp);chop($tmp);#\r\n -> remove.
            push @files,$tmp;
    };
    close $socket;
    my $response=$self->response();
    print STDERR "resp(end LIST) ",$response if $self->{Debug};
    return \@files;
};

sub putblat {
    my ($putorblat,$self,$remote,$local)=@_;
    my $socket;
    my $sock=$self->{'Sock'};
    $local=$remote unless defined($local);
    $self->command("TYPE I");
    my $tmp;
    $tmp=$self->command("PASV");
    $tmp=~/227 [^\d]*(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)/ && do {
        #print "I przyszlo $1 $2 $3 $4 $5 $6, port ",$5*256+$6,"\n";
        my $port=$5*256+$6;
        my $host="$1.$2.$3.$4";
        #print " $host : $port \n";
        $socket = Net::SSLeay::Handle->make_socket($host, $port);
        print "Data link connected.. to $host at $port \n" if $self->{Debug};
    };
    if ($self->{"EncryptData"}==0) {$self->command("PROT C"); };
    $self->command("STOR $remote");

    if ($self->{"EncryptData"}==1) {
    tie(*S2, "Net::SSLeay::Handle", $socket);
    print STDERR "SSL for data connection enabled...\n" if $self->{Debug};
    $socket = \*S2;
    };

    print STDERR "STORE connection opened.\n" if $self->{Debug};
    select($socket);
    #print "selected.\n";
    if ($putorblat=~/put/) {
        CORE::open(L,"$local");
        while ($tmp=<L>) {print $tmp;};#Probably syswrite/sysread would be smarter..
    } else {
        print $local;

    }
    #print "after write...\n";
    select(STDOUT);
    close L;
    close $socket;
    if ($self->{"EncryptData"}==0) {$self->command("PROT P"); };
    my $response=$self->response();
    print  STDERR "resp(afterSTOR) ",$response if $self->{Debug};
};
sub put {
    putblat('put',@_);
};
sub blat {
    putblat('blat',@_);
};
sub get {
    getslurp('get',@_);
};
sub slurp {
    getslurp('slurp',@_);
};

sub getslurp {
    my ($getorslurp,$self,$remote,$local)=@_;
    my $socket;
    my $sock=$self->{'Sock'};
    $local=$remote unless defined($local);
    $self->command("TYPE I");
    my $tmp=$self->command("PASV");
    $tmp=~/227 [^\d]*(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)/ && do {
        #print "I przyszlo $1 $2 $3 $4 $5 $6, port ",$5*256+$6,"\n";
        my $port=$5*256+$6;
        my $host="$1.$2.$3.$4";
        #print " $host : $port \n";
        $socket = Net::SSLeay::Handle->make_socket($host, $port);
        print STDERR "Data link connected to $host at $port..\n" if $self->{Debug};
    };
    if ($self->{"EncryptData"}==0) {$self->command("PROT C"); };
    $self->command("RETR $remote");
    if ($self->{"EncryptData"}==1) {
    tie(*S3, "Net::SSLeay::Handle", $socket);
    print  STDERR "SSL for data connection(RETR) enabled...\n" if $self->{Debug};
    $socket = \*S3;
    };
    my $slurped="";
    if ($getorslurp=~/get/) {
        print STDERR "getorslurp: get\n" if $self->{Debug};
        CORE::open(L,">$local");
        while ($tmp=<$socket>) {print L $tmp; print STDERR ":;" if $self->{Debug};};
        close L;
    } else {
        print STDERR "getorslurp: slurp($getorslurp)\n" if $self->{Debug};
        while ($tmp=<$socket>) {$slurped.=$tmp;print STDERR ":." if $self->{Debug}; };
    };
    close $socket;
    my $response=$self->response();
    print STDERR "resp(afterRETR) ",$response if $self->{Debug};
    if ($self->{"EncryptData"}==0) {$self->command("PROT P"); };
    return $slurped;
};

sub trivialmethod {
   my ($self)=@_;
   return 1;
};



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Net::Lite::FTP - Perl FTP client

=head1 SYNOPSIS

  use Net::Lite::FTP;
  my $tlsftp=Net::Lite::FTP->new();
  $tlsftp->open("ftp.tls.pl","21");
  $tlsftp->user("user");
  $tlsftp->pass("password");
  $tlsftp->cwd("pub");
  my $files=$tlsftp->nlst("*.exe");
  foreach $f (@files) {
	  $tlsftp->get($f);
  };


=head1 DESCRIPTION

Very simple FTP client with support for TLS

=head1 SEE ALSO

L<Net::FTP>
L<Tie::FTP>

ftp(1), ftpd(8), RFC 959
http://war.jgaa.com/ftp/rfc/rfc959.txt

http://war.jgaa.com/ftp/draft/draft-murray-auth-ftp-ssl-03.txt

http://www.ietf.org/internet-drafts/draft-murray-auth-ftp-ssl-10.txt

ftp://ftp.ietf.org/internet-drafts/draft-fordh-ftp-ssl-firewall-01.txt


=head1 AUTHOR

Dariush Pietrzak,'Eyck' E<lt>cpan@ghost.anime.plE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Dariush Pietrzak

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
