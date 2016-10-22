#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';


my $opts = join ' ', @ARGV;

foreach my $file (<lua_test_files/*>) {
	say "test file $file";
	my @lua_lines = `lua $file`;
	my @snow_lines = `perl $opts test.pl $file`;

	my $error = 0;
	if (@snow_lines != @lua_lines) {
		say "\tincorrect number of lines $#lua_lines vs $#snow_lines";
		$error = 1;
	}
	foreach (0 .. $#lua_lines) {
		unless (defined $snow_lines[$_] and $lua_lines[$_] eq $snow_lines[$_]) {
			say "\tinconsistent lines [$_]";
			print "\t\t$lua_lines[$_]" if defined $lua_lines[$_];
			print "\t\t$snow_lines[$_]" if defined $snow_lines[$_];

			$error = 1;
		}
	}

	if ($error) {
		say "test $file failed";
	} else {
		say "test $file successful";
	}
}



