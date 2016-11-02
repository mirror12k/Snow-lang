package Snow::TokenParser;
use strict;
use warnings;

use feature 'say';

use Carp;

use Sugar::IO::File;




sub new {
	my ($class, %opts) = @_;
	my $self = bless {}, $class;

	$self->{ignored_tokens} = [qw/ comment /];

	if (defined $opts{file}) {
		$self->parse_file($opts{file});
	} elsif (defined $opts{text}) {
		$self->parse($opts{text});
	}

	return $self;
}

sub parse_file {
	my ($self, $filepath) = @_;

	$self->{filepath} = Sugar::IO::File->new($filepath);

	my $text = $self->{filepath}->read;
	return $self->parse($text)
}


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


sub parse {
	my ($self, $text) = @_;

	$self->{text} = $text;
	my @tokens;

	my $line_number = 1;
	my $offset = 0;

	while ($text =~ /\G
			($snow_comment_regex)|
			($snow_keywords_regex)|
			($snow_syntax_tokens_regex)|
			($snow_identifier_regex)|
			($snow_literal_string_regex)|
			($snow_numeric_constant_regex)|
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

	foreach my $ignored_token (@{$self->{ignored_tokens}}) {
		@tokens = grep $_->[0] ne $ignored_token, @tokens;
	}

	@tokens = grep { $_->[0] ne 'whitespace' or $_->[1] =~ /\n/ } @tokens;

	$self->{code_tokens} = \@tokens;
	$self->{code_tokens_index} = 0;

	return $self->{code_tokens}
}


sub peek_token {
	my ($self) = @_;
	return undef unless $self->more_tokens;
	return $self->{code_tokens}[$self->{code_tokens_index}]
}

sub current_line_number {
	my ($self) = @_;
	my $index = 0;
	while ($self->more_tokens($index)) {
		return $self->{code_tokens}[$self->{code_tokens_index} + $index][2] unless $self->is_token_type( whitespace => $index );
		$index++;		
	}
	return undef
}

sub next_token {
	my ($self) = @_;
	return undef unless $self->more_tokens;
	return $self->{code_tokens}[$self->{code_tokens_index}++]
}

sub is_token_type {
	my ($self, $type, $offset) = @_;
	return 0 unless $self->more_tokens;
	return $self->{code_tokens}[$self->{code_tokens_index} + ($offset // 0)][0] eq $type
}

sub is_token_val {
	my ($self, $type, $val, $offset) = @_;
	return 0 unless $self->more_tokens;
	return ($self->{code_tokens}[$self->{code_tokens_index} + ($offset // 0)][0] eq $type and
			$self->{code_tokens}[$self->{code_tokens_index} + ($offset // 0)][1] eq $val)
}

sub assert_token_type {
	my ($self, $type, $offset) = @_;
	$self->confess_at_current_offset ("expected token type $type" . (defined $offset ? " (at offset $offset)" : '')
			. " instead got token type $self->{code_tokens}[$self->{code_tokens_index}][0] with value $self->{code_tokens}[$self->{code_tokens_index}][1]")
		unless $self->is_token_type($type, $offset);
}

sub assert_token_val {
	my ($self, $type, $val, $offset) = @_;
	$self->confess_at_current_offset ("expected token type $type with value '$val'" . (defined $offset ? " (at offset $offset)" : '')
			. " instead got token type $self->{code_tokens}[$self->{code_tokens_index}][0] with value $self->{code_tokens}[$self->{code_tokens_index}][1]")
		unless $self->is_token_val($type, $val, $offset);
}

sub assert_step_token_type {
	my ($self, $type) = @_;
	$self->assert_token_type($type);
	return $self->next_token
}

sub assert_step_token_val {
	my ($self, $type, $val) = @_;
	$self->assert_token_val($type, $val);
	return $self->next_token
}

sub confess_at_current_offset {
	my ($self, $msg) = @_;

	my $position;
	if ($self->more_tokens) {
		$position = 'line ' . $self->{code_tokens}[$self->{code_tokens_index}][2];
	} else {
		$position = 'end of file';
	}

	confess "error on $position: $msg";
}

sub more_tokens {
	my ($self, $offset) = @_;
	$offset //= 0;
	return $self->{code_tokens_index} + $offset < @{$self->{code_tokens}}
}


sub dump {
	my ($self) = @_;

	return join "\n", map { "[$_->[2]:$_->[3]] $_->[0] => <$_->[1]>" } @{$self->{code_tokens}}
}

sub dump_at_current_offset {
	my ($self) = @_;

	my @tokens = @{$self->{code_tokens}};
	return join "\n", map { "[$_->[2]:$_->[3]] $_->[0] => <$_->[1]>" } @tokens[$self->{code_tokens_index} .. $#tokens]
}


1;
