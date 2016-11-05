package Snow::TokenParser;
use parent 'Sugar::Lang::Tokenizer';
use strict;
use warnings;

use feature 'say';

use Carp;

use Sugar::IO::File;



our @snow_keywords = qw/
	goto
	break
	last
	next
	redo

	function
	method
	local
	global

	return
	do
	while
	until
	elseif
	else
	if
	unless
	for
	foreach

	nil
	true
	false

	not
	and
	or
/;

our @snow_syntax_tokens = (qw#
	=>
	<=
	>=
	<
	>
	==
	~=
	++
	--
	+=
	-=
	*=
	/=
	..=
	?=

	...
	..
	+
	-
	*
	/
	:
	.
	(
	)
	[
	]
	{
	}
	=
	?
	$
	&
	@
	%
#, '#', ',');

our $snow_keywords_regex = join '|', @snow_keywords;
$snow_keywords_regex = qr/\b(?:$snow_keywords_regex)\b/;

our $snow_syntax_tokens_regex = join '|', map quotemeta, @snow_syntax_tokens;
$snow_syntax_tokens_regex = qr/$snow_syntax_tokens_regex/;


our $snow_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*/;
our $snow_literal_string_regex = qr/'[^']*'|"[^"]*"|\[\[.*?\]\]/s; # TODO: more complex string handling, escape sequences, variable length long brackets
our $snow_numeric_constant_regex = qr/\d+(?:\.\d+)?/; # TODO: implement more complex numerics handling
our $snow_comment_regex = qr/(?:\/\/[^\n]*(?:\n|$)|\/\*.*?\*\/)/s; # TODO: implement variable length long brackets



sub new {
	my ($class, %opts) = @_;

	$opts{token_regexes} = [
		whitespace => qr/\s+/s,
		comment => $snow_comment_regex,
		keyword => $snow_keywords_regex,
		symbol => $snow_syntax_tokens_regex,
		identifier => $snow_identifier_regex,
		literal_string => $snow_literal_string_regex,
		numeric_constant => $snow_numeric_constant_regex,
	];
	$opts{ignored_tokens} = [qw/ comment /];

	my $self = $class->SUPER::new(%opts);
	return $self
}

sub filter_tokens {
	my ($self, @tokens) = @_;
	return grep { $_->[0] ne 'whitespace' or $_->[1] =~ /\n/ } @tokens;
}



1;
