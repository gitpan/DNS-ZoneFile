print "1..1\n";

my $ORIGIN="\$ORIGIN";
my $ZONE = <<EOT;
$ORIGIN .
test IN SOA ns0.test. hostmaster.ns0.test (1998030500 68400 3600
 608400 7200)
 IN NS ns0.test.
 IN NS ns1.test.
 IN MX 10 a.test.
$ORIGIN test.
a in a 10.0.0.1
b in a 10.0.0.2
c in a 10.0.0.3
ns0 in cname a.test.
ns1 in cname b.test.
codix in ns codix.test.
 in mx 10 codix.test.
 in a 10.0.1.1
colondot in ns codix.test.
 in mx 10 codix.test.
 in a 10.0.2.1
$ORIGIN colondot.test.
www in cname colondot.test.
EOT

use DNS::ZoneFile;
my($tmpfile)="/tmp/zonetest-$$";
open(OUT,">$tmpfile") || die;
print OUT $ZONE;
close(OUT);

my($zone)=new DNS::ZoneFile($tmpfile);
my($SHOULDBE)=<<EOT;
$ORIGIN .
test		IN	SOA	ns0.test. hostmaster.ns0.test (
				1998030500  ; Serial Number
				68400       ; Refresh time (secs)
				3600        ; Retry Refresh (secs)
				608400      ; Expiry time (secs)
				7200)       ; Minimum Time to Live (secs)
		IN	NS	ns0.test.
		IN	NS	ns1.test.
		IN	MX	10	a.test.
$ORIGIN test.
a		IN	A	10.0.0.1
b		IN	A	10.0.0.2
c		IN	A	10.0.0.3
codix		IN	NS	codix.test.
		IN	MX	10	codix.test.
		IN	A	10.0.1.1
colondot	IN	NS	codix.test.
		IN	MX	10	codix.test.
		IN	A	10.0.2.1
$ORIGIN colondot.test.
www		IN	CNAME	colondot.test.
$ORIGIN test.
ns0		IN	CNAME	a.test.
ns1		IN	CNAME	b.test.
EOT
my($OUTZONE)=$zone->printZone();
print "not " if($SHOULDBE ne $OUTZONE);
print "ok 1\n";
