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

our $VERSION = '0.03';


# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

use constant BUFSIZE => 4096;
BEGIN {
use Net::SSLeay::Handle qw/shutdown/;
# You only need this if your FTP server requires client certs:
#Net::SSLeay::Handle::_set_cert("/home/eyck/my.pem"); 
#Net::SSLeay::Handle::_set_key("/home/eyck/my.pem");
#
# but if you want this, you need to patch you Net::SSLeay, 
};

sub new($$) {
    my $class=shift;
    my $self={};
    bless $self,$class;
#                            $self->{'DBHandle'}=$dbh;
    $self->{"CreationTime"}=time;
    $self->{"Connected"}=0;

    return $self;
};

sub open($$$) {
   my ($self,$host,$port)=@_;
   my ($data);
   my $sock;
   $sock = Net::SSLeay::Handle->make_socket($host, $port);
   if (sysread($sock,$data,BUFSIZE)) {
	   print STDERR "Dostalem odpowiedz: $data";
   }
    $data="AUTH TLS\n";
    syswrite($sock,$data);
    if (sysread($sock,$data,BUFSIZE)) {
        print STDERR "Dostalem odpowiedz: $data";
    }
    $self->{'RAWSock'}=$sock;

    {
        tie(*S, "Net::SSLeay::Handle", $sock);
        $sock = \*S;
    }
    $self->{'Sock'}=$sock;
#print "Unbuffer\n";
    {
        select($sock);$|=1;select(STDOUT);#unbuffer socket
    }
    return 1;
}
sub command ($$){
    my ($self,$data)=@_;
    print STDERR "Sending: ",$data."\n";
    my $sock=$self->{'Sock'};
    print $sock $data."\n";
    return response($self);
}

sub cwd ($$) {
    my ($self,$data)=@_;
    $self->command("CWD $data");
}


sub response ($) {
    my ($self)=@_;
    my $sock=$self->{'Sock'};
    my ($read,$resp,$code,$cont);
    $read=($resp=<$sock>);
    
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
            print " ----> $read\n";
        } until ($read=~/^\d\d\d\s/);
    };

    if ($code>399) {
        warn "Jaki¶ problem, chyba najlepiej sie wycofac\n";
        warn $resp;
        print "ERR: $resp\n";
        die "Server said we're bad.";
    };
    print STDERR "RECV: ",$resp;
    return $resp;
}


sub trivialmethod {
   my ($self)=@_;
   return 1;
};



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Net::Lite::FTP - Perl extension for booga wooga doo

=head1 SYNOPSIS

  use Net::Lite::FTP;
  booga wooga doo

=head1 DESCRIPTION

Stub documentation for Net::Lite::FTP, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.
Sam jestes negligent!

Booga wooga doo.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Dariush Pietrzak,'Eyck' E<lt>cpan@ghost.anime.plE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Dariush Pietrzak

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
