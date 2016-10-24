#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';


use Data::Dumper;

use Snow::Lua::TokenParser;
use Snow::Lua::SyntaxParser;
use Snow::Lua::SyntaxStringer;




my $file = shift // die "file required";

my $parser = Snow::Lua::SyntaxParser->new(file => $file);
my $stringer = Snow::Lua::SyntaxStringer->new;
print $stringer->to_string($parser->{syntax_tree});


