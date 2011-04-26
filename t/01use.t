#!/usr/bin/perl -w
use strict;

use Test::More tests => 3;

BEGIN {
	use_ok( 'Test::XHTML' );
	use_ok( 'Test::XHTML::Valid' );
	use_ok( 'Test::XHTML::WAI' );
}

