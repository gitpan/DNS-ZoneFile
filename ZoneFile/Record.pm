#!/usr/bin/perl

# DNS::ZoneFile::Record written by Matthew Byng-Maddick <matthew@codix.net>

package DNS::ZoneFile::Record;

=head1 NAME

B<DNS::ZoneFile::Record> - single DNS record in a zone database

=head1 SYNOPSIS

C<use DNS::ZoneFile::Record;>

$rec=B<DNS::ZoneFile::Record>->new(I<origin>,I<name>,I<type>,I<data>...);

$name=$rec->B<Name>(I<name>);

$type=$rec->B<Type>(I<type>);

$address=$rec->B<Addr>(I<address>);

$serial=$rec->B<Serial>(I<serialno>);

$mxcost=$rec->B<MXCost>(I<MXcost>);

@record=$rec->B<getRecord>();

=head1 DESCRIPTION

B<DNS::ZoneFile::Record> is a companion object model to B<DNS::ZoneFile> to provide
a seperate object and methods for each of the records in a zone.

The object methods are as follows:

=head2 B<new>(I<origin>,I<name>,I<type>,I<data>...)

The B<new> method is to create a new object. I<origin> is used for the 
value of the $ORIGIN system in the database, so that the record can be
canonicalised. I<name> is the name relative to I<origin>, or ending in
a period ('.') is the canonical name for this record. I<type> is the
type of this record, and affects what I<data> the new method expects,
and how it stores it internally. Valid types are:

=over 4

=item SOA	

This is a start of authority record, and expects 7 I<data> arguments,
in order the host, the hostmaster, the serial number, the refresh time,
the retry time, the expiry time and the minimum time to live of the records.

=item NS

This is a nameserver record, detailing nameservers for a domain. This
just expects one I<data> argument viz the name of the server.

=item A

This is a forward record, pointing a name to an IP address, so the I<data>
argument expected is a dotted quad IP address.

=item PTR

This is a reverse record, only really valid in .in-addr.arpa domains, and
points a number to a name.

=item MX

This is a mail exchanger record. The arguments expected are in order the
cost of using that server (or reverse priority) and the name of the server.

=item CNAME

This is a canonical name record, it points one name as a redirector for
another. Its one I<data> argument is the name to point to.

=back

=head2 B<Name>(I<name>)

Returns the full DNS name of the record, also sets the name if an argument
is provided.

=head2 B<Type>(I<type>)

Returns the type of the record, also sets the type if an argument
is provided, although at present this is not recommended, because
no data is moved internally, so things could break.

=head2 B<Addr>(I<addr>)

Returns the address that this record points to, this differs in meaning
depending on the record type, the main difference being in the I<start
of authority> records, where the address returned is the authoritative
host for this zone. This value can also be set with the optional argument.

=head2 B<Serial>(I<serialno>)

Returns the serial number of the zone file if this is an SOA record, also
sets it if an argument is provided.

=head2 B<MXCost>(I<MXcost>)

Returns the cost of this server if this is an MX record, also
sets it if an argument is provided.

=head2 B<getRecord>()

Returns the data for this record in the order that it was input (see
above B<new>() method).

=head1 COMMENTS

This is currently alpha software, internal structures are likely to change
at any time.

=head1 AUTHOR

Matthew Byng-Maddick <matthew@codix.net>

=head1 SEE ALSO

B<DNS::ZoneFile>

=cut

sub new
	{
	my($package,$origin,$name,$type,@data)=@_;
	my(%h);
	$h{Name}=canonicalise($origin,$name);
	$h{Type}=uc $type;
	if($h{Type} eq "SOA")
		{
		return(0) if($#data!=6);
		$h{Host}=$data[0];
		$h{Hostmaster}=$data[1];
		$h{Serial}=$data[2];
		$h{Refresh}=$data[3];
		$h{Retry}=$data[4];
		$h{Expire}=$data[5];
		$h{Ttl}=$data[6];
		}
	elsif($h{Type} eq "NS")
		{
		$h{Server}=canonicalise($origin,$data[0]);
		}
	elsif($h{Type} eq "A")
		{
		return(0) if($data[0]!~/^\d+\.\d+\.\d+\.\d+$/);
		$h{IPAddr}=canonicalise($origin,$data[0]);
		}
	elsif($h{Type} eq "PTR")
		{
		$h{DNSName}=canonicalise($origin,$data[0]);
		}
	elsif($h{Type} eq "CNAME")
		{
		$h{DNSName}=canonicalise($origin,$data[0]);
		}
	elsif($h{Type} eq "MX")
		{
		$h{Cost}=$data[0];
		$h{Server}=$data[1];
		}
	return(bless(\%h));
	}

sub Name
	{
	if($_[1])
		{
		$_[0]->{Name}=$_[1];
		}
	return($_[0]->{Name});
	}

sub Type
	{
	if($_[1])
		{
		$_[0]->{Type}=$_[1];
		}
	return($_[0]->{Type});
	}

sub Addr
	{
	my(%hash)=(	"SOA"	=> "Host",
			"NS"	=> "Server",
			"MX"	=> "Server",
			"A"	=> "IPAddr",
			"PTR"	=> "DNSName",
			"CNAME"	=> "DNSName"
		);
	$addr=$hash{$_[0]->Type()};
	if($_[1])
		{
		$_[0]->{$hash{$_[0]->Type()}}=lc($_[1]);
		}
	return($_[0]->{$hash{$_[0]->Type()}});
	}

sub Serial
	{
	return(0) if($_[0]->Type() ne "SOA");
	if($_[1])
		{
		$_[0]->{Serial}=$_[1];
		}
	return($_[0]->{Serial});
	}

sub MXCost
	{
	return(0) if($_[0]->Type() ne "MX");
	if($_[1])
		{
		$_[0]->{Cost}=$_[1];
		}
	return($_[0]->{Cost});
	}

sub getRecord
	{
	if($_[0]->Type() eq "SOA")
		{
		return($_[0]->{Host},$_[0]->{Hostmaster},
			$_[0]->{Serial},$_[0]->{Refresh},
			$_[0]->{Retry},$_[0]->{Expire},
			$_[0]->{Ttl});
		}
	elsif($_[0]->Type() eq "NS" || $_[0]->Type() eq "A" ||
		$_[0]->Type() eq "PTR" || $_[0]->Type() eq "CNAME")
		{
		return($_[0]->Addr());
		}
	elsif($_[0]->Type() eq "MX")
		{
		return($_[0]->{Cost},$_[0]->{Server});
		}
	}

sub canonicalise
	{
	my($origin,$addr)=@_;
	$addr=lc($addr);
	$origin="" if($origin eq ".");
	return $addr.".".$origin
		if($addr!~/^\d+\.\d+\.\d+\.\d+$/ && $addr !~ /\.$/);
	return $addr;
	}

1;
