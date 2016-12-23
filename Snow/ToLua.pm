#!/usr/bin/env perl
package Snow::ToLua;
use strict;
use warnings;

use feature 'say';

use Snow::SyntaxTranslator;
use Snow::Lua::SyntaxStringer;



sub compile_snow_to_lua {
	my ($filepath) = @_;

	my $parser = Snow::SyntaxTranslator->new(filepath => $filepath);
	$parser->parse;
	my $stringer = Snow::Lua::SyntaxStringer->new;
	return $stringer->to_string($parser->{syntax_tree});
}



sub main {
	say compile_snow_to_lua $_ foreach @_;
}



caller or main(@ARGV);
