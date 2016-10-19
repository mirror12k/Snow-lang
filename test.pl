#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';


use Data::Dumper;

use Snow::Lua::TokenParser;
use Snow::Lua::SyntaxParser;
use Snow::Lua::SyntaxInterpreter;
use Snow::Lua::Bytecode;




my $file = shift // die "file required";

my $parser = Snow::Lua::Bytecode->new(file => $file);
say $parser->dump_bytecode;
# say Dumper $parser->{bytecode_chunk};


# while ($parser->more_tokens) {
# 	say Dumper $parser->next_token;
# }
# say Dumper $parser->{syntax_tree};

# $parser->{filepath} = Sugar::IO::File->new("$file.rep");
# $parser->to_file;



