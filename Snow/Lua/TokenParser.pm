package Snow::Lua::TokenParser;
use strict;
use warnings;

use feature 'say';

use Sugar::IO::File;
use Data::Dumper;




sub new {
	my ($class, %opts) = @_;
	my $self = bless {}, $class;

	if (defined $opts{file}) {
		$self->parse_file($opts{file});
	} elsif (defined $opts{text}) {
		$self->parse($opts{text});
	}

	return $self;
}

sub parse_file {
	my ($self, $filepath) = @_;

	$self->{filepath} = $filepath;

	my $text = Sugar::IO::File->new($filepath)->read;
	return $self->parse($text)
}


our @lua_keywords = qw/
	and
	break
	do
	else
	elseif
	end
	false
	for
	function
	goto
	if
	in
	local
	nil
	not
	or
	repeat
	return
	then
	true
	until
	while
/;

our @lua_syntax_tokens = (qw#
	+
	-
	*
	//
	/
	%
	^
	&
	~
	|
	<<
	>>
	==
	~=
	<=
	>=
	<
	>
	=
	(
	)
	{
	}
	[
	]
	::
	;
	:
	...
	..
	.
#, '#', ',');

our $lua_keywords_regex = join '|', @lua_keywords;
$lua_keywords_regex = qr/\b$lua_keywords_regex\b/;

our $lua_syntax_tokens_regex = join '|', map quotemeta, @lua_syntax_tokens;
$lua_syntax_tokens_regex = qr/$lua_syntax_tokens_regex/;


our $lua_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*/;
our $lua_literal_string_regex = qr/'[^']*'|"[^"]*"|\[\[.*?\]\]/s; # TODO: more complex string handling, escape sequences, variable length long brackets
our $lua_numeric_constant_regex = qr/\d+(?:\.\d+)?/; # TODO: implement more complex numerics handling
our $lua_comment_regex = qr/--(?:\[\[.*?\]\]|[^\n]*\n)/s; # TODO: implement variable length long brackets


sub parse {
	my ($self, $text) = @_;

	$self->{text} = $text;
	my @tokens;

	my $line_number = 1;
	my $offset = 0;

	while ($text =~ /\G
			($lua_comment_regex)|
			($lua_keywords_regex)|
			($lua_syntax_tokens_regex)|
			($lua_identifier_regex)|
			($lua_literal_string_regex)|
			($lua_numeric_constant_regex)|
			(\s+)
			/gcsx) {
		# say "debug: ", pos $text;
		if (defined $1) {
			push @tokens, [ comment => $&, $line_number, $offset ]
		} elsif (defined $2) {
			push @tokens, [ keyword => $&, $line_number, $offset ]
		} elsif (defined $3) {
			push @tokens, [ symbol => $&, $line_number, $offset ]
		} elsif (defined $4) {
			push @tokens, [ identifier => $&, $line_number, $offset ]
		} elsif (defined $5) {
			push @tokens, [ literal_string => $&, $line_number, $offset ]
		} elsif (defined $6) {
			push @tokens, [ numeric_constant => $&, $line_number, $offset ]
		} else {
			push @tokens, [ whitespace => $&, $line_number, $offset ]
		}
		$offset = pos $text;
		$line_number += ()= ($& =~ /\n/g);
	}


	die "error parsing file at " . substr ($text, pos $text // 0) if not defined pos $text or pos $text != length $text;

	$self->{tokens} = \@tokens;

	say foreach $self->dump;
}


sub dump {
	my ($self) = @_;

	return map { "[$_->[2]] $_->[0] => <$_->[1]>" } @{$self->{tokens}};
}


1;
