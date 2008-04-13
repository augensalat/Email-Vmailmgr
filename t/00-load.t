#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Email::Vmailmgr' );
}

diag( "Testing Email::Vmailmgr $Email::Vmailmgr::VERSION, Perl $], $^X" );
