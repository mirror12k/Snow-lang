#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Sugar::Test::Barrage;


my $opts = join ' ', @ARGV;

Sugar::Test::Barrage->new(
	test_files_dir => 'snow_test_files/run_tests',
	test_files_regex => qr/\.snow$/,
	control_processor => "cat \$testfile.expected",
	test_processor => "perl $opts snow_test.pl \$testfile | lua",
)->run;


