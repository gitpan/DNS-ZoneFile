print "1..3\n";

my $ORIGIN = "\$ORIGIN";
my $ZONE = <<EOT;
$ORIGIN .
test	IN	SOA	ns0.test. hostmaster.ns0.test. (1998030500 68400
				3600 608400 7200)
EOT

use DNS::ZoneFile;
my($year,$month,$day)=((localtime())[5]+1900,(localtime())[4]+1,
	(localtime())[3]);
my($tmpfile)="/tmp/zonetest-$$";
open(OUT,">$tmpfile") || die;
print OUT $ZONE;
close(OUT);

my($zone)=new DNS::ZoneFile($tmpfile);
my($serial)=$zone->serial();
print "Serial Number (before update)  : $serial\n";
$zone->updateSerial();
$serial=$zone->serial();
print "Serial Number (after update)   : $serial\n";
print "not " if($serial eq "1998030500");
print "ok 1\n";
my($sy,$sm,$sd,$sv)=unpack("a4a2a2a2",$serial);
print "not " unless(($sy==$year) && ($sm==$month) && ($sd==$day) && ($sv==0));
print "ok 2\n";
$zone->updateSerial();
$serial=$zone->serial();
print "Serial Number (after update 2) : $serial\n";
($sy,$sm,$sd,$sv)=unpack("a4a2a2a2",$serial);
print "not " unless(($sy==$year) && ($sm==$month) && ($sd==$day) && ($sv==1));
print "ok 3\n";
