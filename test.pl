#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';



use Snow::Lua::TokenParser;




my $file = shift // die "file required";

my $parser = Snow::Lua::TokenParser->new(file => $file);





