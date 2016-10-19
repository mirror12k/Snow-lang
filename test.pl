#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';


use Data::Dumper;

use Snow::Lua::TokenParser;
use Snow::Lua::SyntaxParser;
use Snow::Lua::SyntaxInterpreter;
use Snow::Lua::Bytecode;
use Snow::Lua::BytecodeInterpreter;




my $file = shift // die "file required";

my $int = Snow::Lua::BytecodeInterpreter->new(file => $file);
$int->execute;
# my $parser = Snow::Lua::Bytecode->new(file => $file);
# say $parser->dump_bytecode;
# say Dumper $parser->{bytecode_chunk};


# while ($parser->more_tokens) {
# 	say Dumper $parser->next_token;
# }
# say Dumper $parser->{syntax_tree};

# $parser->{filepath} = Sugar::IO::File->new("$file.rep");
# $parser->to_file;



