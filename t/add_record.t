print "1..3\n";

my $ORIGIN="\$ORIGIN";
my $ZONE = <<EOT;
$ORIGIN .
test	IN	SOA	ns0.test. hostmaster.ns0.test. (1998030500 68400
				3600 608400 7200)
	IN	NS	ns0.test.
	IN	NS	ns1.test.
	IN	MX	10	a.test.
$ORIGIN test.
a	IN	A	10.0.0.1
b	IN	A	10.0.0.2
c	IN	A	10.0.0.3
ns0	IN	CNAME	a
ns1	IN	CNAME	b
codix	IN	A	10.0.1.1
codix	IN	MX	10	codix.test.
codix	IN	NS	codix.test.
EOT

use DNS::ZoneFile;
my($tmpfile)="/tmp/zonetest-$$";
open(OUT,">$tmpfile") || die;
print OUT $ZONE;
close(OUT);

my($zone)=new DNS::ZoneFile($tmpfile);
my(@arr)=$zone->getData();
for(@arr)
	{
	print $_->Name(),"\t",$_->Type(),"\t",$_->Addr(),"\n";
	}
$zone->addRecord("d.test","A","10.0.0.4");
@arr=$zone->getData();
print "not " if($arr[$#arr]->Type() ne "A");
print "ok 1\n";
print "not " if($arr[$#arr]->Name() ne "d.test.");
print "ok 2\n";
print "not " if($arr[$#arr]->Addr() ne "10.0.0.4");
print "ok 3\n";
