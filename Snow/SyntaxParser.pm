package Snow::SyntaxParser;
use parent 'Snow::TokenParser';
use strict;
use warnings;

use feature 'say';

use Carp;
use Data::Dumper;




sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);
	return $self;
}



sub parse {
	my ($self, $text) = @_;
	$self->SUPER::parse($text);

	$self->{syntax_tree} = $self->parse_syntax_block;
	say $self->dump_at_current_offset and $self->confess_at_current_offset('more tokens found after end of code') if $self->more_tokens;

	return $self->{syntax_tree}
}



sub parse_syntax_block {
	my ($self, $whitespace_prefix) = @_;
	$whitespace_prefix = $whitespace_prefix // '';

	my @block;
	my $line_number = $self->current_line_number;
	while (my @statements = $self->parse_syntax_statements($whitespace_prefix)) {
		push @block, map { $_->{line_number} = $line_number; $_ } @statements;
		$line_number = $self->current_line_number;
	}
	# my $statement = $self->parse_syntax_return_statement;
	# push @block, $statement if defined $statement;


	return \@block
}



sub parse_syntax_statements {
	my ($self, $whitespace_prefix) = @_;

	return unless $self->more_tokens;

	while ($self->is_token_type( 'whitespace' )) {
		my $prefix = $self->peek_token->[1] =~ s/\n([^\n]*)$/$1/r;
		say "got prefix: '$prefix'";
		if (($self->more_tokens(1) and $self->is_token_type( 'whitespace', 1 )) or $prefix =~ /^$whitespace_prefix/) {
			say "skipping whitespace";
			$self->next_token;
		} else {
			say "whitespace end";
			return
		}
	}

	my @statements;
	if ($self->is_token_type( 'identifier' ) and $self->is_token_val( symbol => ':', 1 )) {
		say "got label statement";
		my $identifier = $self->next_token->[1];
		$self->next_token;
		push @statements, { type => 'label_statement', identifier => $identifier };

	} elsif ($self->is_token_val( keyword => 'do' )) {
		$self->next_token;
		push @statements, { type => 'block_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };
	}

	return @statements
}

sub dump_syntax {
	my ($self, $syntax) = @_;
	$syntax = $syntax // $self->{syntax_tree};

	return Dumper $syntax;
}

1;


