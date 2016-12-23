#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Sugar::Test::Barrage;


my $opts = join ' ', @ARGV;

Sugar::Test::Barrage->new(
	test_files_dir => 'lua_test_files',
	control_processor => "lua \$testfile",
	test_processor => "perl $opts lua_test.pl \$testfile",
)->run;


