require 5.004;
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=>	'DNS::ZoneFile',
	'VERSION_FROM'	=>	'ZoneFile.pm',
	dist		=>	{ COMPRESS => 'gzip -9f', SUFFIX => 'gz'}
	);
