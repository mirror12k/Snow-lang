#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';


use Data::Dumper;

use Snow::Lua::TokenParser;




my $file = shift // die "file required";

my $parser = Snow::Lua::TokenParser->new(file => $file);

while ($parser->more_tokens) {
	say Dumper $parser->next_token;
}
# $parser->{filepath} = Sugar::IO::File->new("$file.rep");
# $parser->to_file;



