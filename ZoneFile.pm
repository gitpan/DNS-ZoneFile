#!/usr/bin/perl

# DNS::ZoneFile, written by Matthew Byng-Maddick <matthew@codix.net>

package DNS::ZoneFile;

$VERSION="0.92";

=head1 NAME

B<DNS::ZoneFile> - Object management of a DNS Zone

=head1 SYNOPSIS

C<use DNS::ZoneFile;>

$zone=B<DNS::ZoneFile>->new(I<zonefilename>,I<args>...);

@arr=$zone->getRecord(I<name>,I<type>);

$zone->addRecord(I<name>,I<type>,I<data>...);

$zone->delRecord(I<name>,I<type>);

$zone->sortZone();

$zone->updateSerial();

$zone->serial();

B<print> $zone->printZone();

=head1 DESCRIPTION

The B<DNS::ZoneFile> module provides for users to manipulate a DNS Zone database using an object
oriented model. The B<DNS::ZoneFile> object is a store for lots of B<DNS::ZoneFile::Record> objects,
and can manipulate some of the more useful bits of the zone file, such as C<updateSerial>.

Object methods for the B<DNS::ZoneFile> object:

=head2 B<new>(I<file>,I<args>...)

The B<new>() method takes as its argument the name of a zone file to read in, this builds the
zone database into memory. You must call this before trying to use any of the methods below.
I know that I should do this in a non file-based way, and I'll probably do that in the next
release. The I<args> are used to populate a hash of preferences. So far the only key that is
supported is I<AllNames>, which, if set to true will print out all of the names in the
B<printZone>() method, instead of blank spacing them.

=head2 B<getRecord>(I<name>,I<type>)

The B<getRecord>() method will try to get all of the records matching a full (canonical) name
with an optional I<type> argument, such that you might do, for example
$zone->B<getRecord>('codix.net.', 'mx');

=head2 B<addRecord>(I<name>,I<type>,I<data>...)

The B<addRecord>() method is exactly that, it does minimal checking, except that it won't
allow you to add a SOA record, as there should only ever be one of those per zone file. The
data is in most cases just one address, unless the record is an MX record, in which case
the first argument is the MX cost.

=head2 B<delRecord>(I<name>,I<type>)

The B<delRecord> method deletes a record from the zone database. The type argument is
optional, if missed, it will delete all records matching the supplied name.

=head2 B<sortZone>()

B<sortZone> is called automatically whenever a B<printZone>() is called. It sorts the
zone file into a reasonable order, to be able to print. It will also make sure that the
I<start of authority> for the zone is at the top of the file.

=head2 B<updateSerial>()

B<updateSerial> is just that, it updates the serial number for the database for an edit.

=head2 B<serial>()

A read only method to read the serial number for this zone.

=head2 B<printZone>()

B<printZone> returns the zone file as sorted and updated, in a form which you can then just
output to the zone file, with the correct I<start of authority> record.

=head1 COMMENTS

This is currently alpha software, internal structures are likely to change at any time.

=head1 AUTHOR

Matthew Byng-Maddick C<<matthew@codix.net>>

=head1 SEE ALSO

B<DNS::ZoneFile::Record>,L<bind(8)>

=cut

use strict;
use DNS::ZoneFile::Record;

sub new
	{
	my($package)=shift;
	my($file)=shift;
	return(undef) unless(open(ZONE,$file));
	my($origin);
	my(@arr);
	my($flag)="";
	my($multiline);
	my($name,$type);
	# Fix as suggested by HO to fix $/ problems
	my($oldRS)=$/;
	$/="\n";
	while(<ZONE>)
		{
		s/;.*$//g;
		if($flag eq "in_soa")
			{
			$multiline.=$_;
			if(/\)/)
				{
				$flag="soa_done";
				push(@arr,DNS::ZoneFile::Record->new($origin,$name,$type,parseSOA($multiline)));
				}
			}
		if(/\$ORIGIN\s+(\.)?(\S*)/i)
			{
			$origin=$2;
			}
		elsif(/\s*((\S*[^0-9\s]+\S*)\s+)?(\d+\s+)?IN\s+(\S+)\s+(\S.*)\s*$/i)
			{
			my(%h);
			if($2)
				{
				$name=$2;
				}
			$type=uc($4);
			if($type eq "SOA" && $flag ne "soa_done")
				{
				if(!/\)/)
					{
					$flag="in_soa";
					$multiline=$5;
					}
				else
					{
					$flag="soa_done";
					push(@arr,DNS::ZoneFile::Record->new($origin,$name,$type,parseSOA($5)));
					}
				}
			elsif($type eq "MX")
				{
				push(@arr,DNS::ZoneFile::Record->new($origin,$name,$type,(split/\s+/,$5)));
				}
			else
				{
				push(@arr,DNS::ZoneFile::Record->new($origin,$name,$type,$5));
				}
			}
		}
	close(ZONE);
	$/=$oldRS;
	my(%ret);
	$ret{Data}=\@arr;
	$ret{Pref}={@_};
	return(bless \%ret);
	}

sub sortZone
	{
	my($REF)=@_;
	my(@arr)=$REF->getData();
	my(@ar2);
	@ar2=sort
		{
		return(1) if($b->Type() eq "SOA");
		return(-1) if($a->Type() eq "SOA");
		my(@aarr)=split/\./,$a->Name();
		my(@barr)=split/\./,$b->Name();
		@aarr=reverse @aarr;
		@barr=reverse @barr;
		my $i=0;
		for($i=0;$aarr[$i] && $barr[$i];$i++)
			{
			return($aarr[$i] cmp $barr[$i])
				if($aarr[$i] cmp $barr[$i]);
			}
		if($aarr[$i] && !$barr[$i])
			{
			return(1);
			}
		elsif($barr[$i] && !$aarr[$i])
			{
			return(-1);
			}
		else
			{
			return(1) if($b->Type() eq "NS");
			return(-1) if($a->Type() eq "NS");
			return(1) if($b->Type() eq "MX");
			return(-1) if($a->Type() eq "MX");
			}
		} @arr;
	$REF->{Data}=\@ar2;
	return(1);
	}

sub addRecord
	{
	my($REF,$name,$type,@data)=@_;
	push(@{$REF->{Data}},DNS::ZoneFile::Record->new(".",$name,$type,@data)) if($type ne "SOA");
	}

sub delRecord
	{
	my($REF,$name,$type)=@_;
	my($count)=0;
	return(0) if(!$name);
	my(@arr)=$REF->getData();
	my(@ar2);
	for(@arr)
		{
		if($type)
			{
			push(@ar2,$_) unless($type eq $_->Type() && $name eq $_->Name());
			$count++ if($type eq $_->Type() && $name eq $_->Name());
			}
		else
			{
			push(@ar2,$_) unless($name eq $_->Name());
			$count++ if($name eq $_->Name());
			}
		}
	$REF->{Data}=\@ar2;
	return($count);
	}

sub getRecord
	{
	my($REF,$name,$type)=@_;
	$type=uc($type);
	my(@arr)=$REF->getData();
	my(@ret);
	for(@arr)
		{
		my(@ar2)=$_->getRecord();
		if($type)
			{
			push(@ret,\@ar2) if($name eq $_->Name() && $type eq $_->Type());
			}
		else
			{
			push(@ret,\@ar2) if($name eq $_->Name());
			}
		}
	return(@ret);
	}

sub serial
	{
	my($REF)=@_;
	my(@arr)=$REF->getData();
	for(@arr)
		{
		return($_->Serial()) if($_->Type() eq "SOA");
		}
	}

sub getData
	{
	return(@{$_[0]->{Data}});
	}

sub updateSerial
	{
	my($REF)=@_;
	my($snum);
	for($REF->getData())
		{
		if($_->Type() eq "SOA")
			{
			my($oldyear,$oldmonth,$oldday,$oldversion)=unpack("a4a2a2a2",$_->Serial());
			my(@arr)=localtime();
			if(($arr[5]+1900==$oldyear)&&($arr[4]+1==$oldmonth)&&($arr[3]==$oldday))
				{
				$snum="0"x(4-length($oldyear)).$oldyear;
				$snum.="0"x(2-length($oldmonth)).$oldmonth;
				$snum.="0"x(2-length($oldday)).$oldday;
				$snum.="0"x(2-length(++$oldversion)).$oldversion;
				}
			else
				{
				$snum="0"x(4-length($arr[5]+1900)).($arr[5]+1900);
				$snum.="0"x(2-length($arr[4]+1)).($arr[4]+1);
				$snum.="0"x(2-length($arr[3])).$arr[3];
				$snum.="00";
				}
			$_->Serial($snum);
			}
		}
	}

sub printZone
	{
	my($REF)=@_;
	my($origin,$oldname,$zone)=("","","");
	$REF->sortZone();
	my(@data)=$REF->getData();
	for(@data)
		{
		my($neworig)="";
		my($name)=$_->Name();
		if($name=~/^([^\.]+)\.$/)
			{
			$name=$1;
			$neworig=".";
			}
		elsif($name=~/^([^\.]+)\.(.*)$/)
			{
			$name=$1;
			$neworig=$2;
			}
		if($origin ne $neworig)
			{
			$zone.="\$ORIGIN $neworig\n";
			$oldname="";
			}
		if($REF->{Pref}->{AllNames})
			{
			$zone.=$name."\t"x(length($name)>7?1:2);
			}
		else
			{
			$zone.=($name ne $oldname)?$name."\t"x(length($name)>7?1:2):"\t\t";
			}
		$zone.="IN\t".$_->Type()."\t";
		$oldname=$name;
		$origin=$neworig;
		if($_->Type() eq "SOA")
			{
			$zone.=($_->getRecord())[0]." ".($_->getRecord())[1]." (\n";
			$zone.="\t\t\t\t".($_->getRecord())[2]." "x(11-length(($_->getRecord())[2])).
				" ; Serial Number\n";
			$zone.="\t\t\t\t".($_->getRecord())[3]." "x(11-length(($_->getRecord())[3])).
				" ; Refresh time (secs)\n";
			$zone.="\t\t\t\t".($_->getRecord())[4]." "x(11-length(($_->getRecord())[4])).
				" ; Retry Refresh (secs)\n";
			$zone.="\t\t\t\t".($_->getRecord())[5]." "x(11-length(($_->getRecord())[5])).
				" ; Expiry time (secs)\n";
			$zone.="\t\t\t\t".($_->getRecord())[6].")"." "x(11-length(($_->getRecord())[6])).
				"; Minimum Time to Live (secs)";
			}
		elsif($_->Type() eq "MX")
			{
			$zone.=($_->getRecord())[0]."\t".($_->getRecord())[1];
			}
		else
			{
			$zone.=$_->Addr();
			}
		$zone.="\n";
		}
	return($zone);
	}

sub parseSOA
	{
	my($soa)=@_;
	return($1,$2,$3,$4,$5,$6,$7)
		if($soa=~/^(\S+)\s+(\S+)\s*\(\s*(\d+)\s+(\d+[smhdwSMHDW]?)\s+(\d+[smhdwSMHDW]?)\s+(\d+[smhdwSMHDW]?)\s+(\d+[smhdwSMHDW]?)\s*\)/s);
	}

1;
