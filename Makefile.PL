use strict;
use warnings;
use inc::Module::Install;

# Define metadata
name		'Email-Vmailmgr';
author		'Bernhard Graf <perl-email-vmailmgr@movingtarget.de>';
version_from	'lib/Email/Vmailmgr.pm';
abstract_from	'lib/Email/Vmailmgr.pm';
license		'perl';

# Specific dependencies
build_requires	'Test::More' => 0;
requires	'Carp' => 0;
requires	'Class::Accessor' => 0;
requires	'Class::Accessor::Fast' => 0;
requires	'Class::Data::Inheritable' => 0;
requires	'IO::Handle' => 0;
requires	'Socket' => 0;

WriteAll;
