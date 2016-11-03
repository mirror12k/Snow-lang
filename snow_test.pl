#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';


use Data::Dumper;

use Snow::Lua::TokenParser;
use Snow::Lua::SyntaxParser;
use Snow::Lua::SyntaxStringer;
use Snow::TokenParser;
use Snow::SyntaxParser;
use Snow::SyntaxTranslator;




my $file = shift // die "file required";

# my $parser = Snow::Lua::SyntaxParser->new(file => $file);
# my $stringer = Snow::Lua::SyntaxStringer->new;
# print $stringer->to_string($parser->{syntax_tree});


# my $parser = Snow::TokenParser->new(file => $file);
# say $parser->dump;


# my $parser = Snow::SyntaxParser->new(file => $file);
# say $parser->dump_syntax;


my $parser = Snow::SyntaxTranslator->new(filepath => $file);
$parser->parse;
my $stringer = Snow::Lua::SyntaxStringer->new;
say $stringer->to_string($parser->{syntax_tree});


