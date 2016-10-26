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
	say "parse_syntax_block: '$whitespace_prefix'";
	while (my @statements = $self->parse_syntax_statements($whitespace_prefix)) {
		push @block, map { $_->{line_number} = $line_number; $_ } @statements;
		$line_number = $self->current_line_number;
	}
	# my $statement = $self->parse_syntax_return_statement;
	# push @block, $statement if defined $statement;


	return \@block
}


sub parse_syntax_whitespace {
	my ($self, $whitespace_prefix) = @_;
	while ($self->is_token_type( 'whitespace' )) {
		my $prefix = $self->peek_token->[1] =~ s/^.*\n([^\n]*)$/$1/rs;
		say "got prefix: '$prefix'";
		if (($self->more_tokens(1) and $self->is_token_type( 'whitespace', 1 )) or $prefix =~ /^$whitespace_prefix/) {
			say "skipping whitespace";
			$self->next_token;
			return 1 unless $self->is_token_type( 'whitespace' );
		} else {
			say "whitespace end";
			return 0
		}
	}
}

# if the next token is on appropriate whitespace positioning and matches
sub is_far_next_token {
	my ($self, $type, $val, $whitespace_prefix) = @_;

	my $index = $self->{code_tokens_index};
	say "debug $index, '$whitespace_prefix'";
	if ($self->parse_syntax_whitespace($whitespace_prefix)) {
		say "debug whitespace parsed";
		if ($self->is_token_val($type => $val)) {
			return 1
		} else {
			$self->{code_tokens_index} = $index;
			return 0
		}
	} else {
		$self->{code_tokens_index} = $index;
		return 0
	}
}

sub parse_syntax_statements {
	my ($self, $whitespace_prefix) = @_;

	say "debug parse_syntax_statements '$whitespace_prefix'";

	return unless $self->more_tokens;

	return unless $self->parse_syntax_whitespace($whitespace_prefix);

	my @statements;
	if ($self->is_token_type( 'identifier' ) and $self->is_token_val( symbol => ':', 1 )) {
		my $identifier = $self->next_token->[1];
		$self->next_token;
		push @statements, { type => 'label_statement', identifier => $identifier };

	} elsif ($self->is_token_val( keyword => 'goto' )) {
		$self->next_token;
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		push @statements, { type => 'goto_statement', identifier => $identifier };

	} elsif ($self->is_token_val( keyword => 'break' )) {
		$self->next_token;
		push @statements, { type => 'break_statement' };
	} elsif ($self->is_token_val( keyword => 'next' )) {
		$self->next_token;
		push @statements, { type => 'next_statement' };
	} elsif ($self->is_token_val( keyword => 'redo' )) {
		$self->next_token;
		push @statements, { type => 'redo_statement' };
	} elsif ($self->is_token_val( keyword => 'last' )) {
		$self->next_token;
		push @statements, { type => 'last_statement' };

	} elsif ($self->is_token_val( keyword => 'do' )) {
		$self->next_token;
		push @statements, { type => 'block_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };

	} elsif ($self->is_token_val( keyword => 'while' )) {
		$self->next_token;
		my $expression = $self->parse_syntax_expression;
		push @statements, { type => 'while_statement', expression => $expression, block => $self->parse_syntax_block("$whitespace_prefix\t") };
	} elsif ($self->is_token_val( keyword => 'if' )) {
		say "debug if '$whitespace_prefix'";
		$self->next_token;
		my $expression = $self->parse_syntax_expression;
		my $statement = { type => 'if_statement', expression => $expression, block => $self->parse_syntax_block("$whitespace_prefix\t") };
		my $branch_statement = $statement;

		while ($self->is_far_next_token(keyword => 'elseif', $whitespace_prefix)) {
			$self->next_token;
			$expression = $self->parse_syntax_expression;
			$branch_statement->{branch} = { type => 'elseif_statement', expression => $expression, block => $self->parse_syntax_block("$whitespace_prefix\t") };
			$branch_statement = $branch_statement->{branch};
		}

		if ($self->is_far_next_token(keyword => 'else', $whitespace_prefix)) {
			say "debug";
			$self->next_token;
			$branch_statement->{branch} = { type => 'else_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };
		}

		push @statements, $statement;
	}

	return @statements
}

sub dump_syntax {
	my ($self, $syntax) = @_;
	$syntax = $syntax // $self->{syntax_tree};

	return Dumper $syntax;
}



our @snow_syntax_unary_operations = ('not', '#', '-', '~');
our %snow_syntax_unary_operations_hash;
@snow_syntax_unary_operations_hash{@snow_syntax_unary_operations} = ();

sub parse_syntax_expression {
	my ($self) = @_;

	my $expression;
	if ($self->is_token_val( keyword => 'nil' )) {
		$self->next_token;
		$expression = { type => 'nil_constant' };

	} elsif ($self->is_token_val( keyword => 'true' ) or $self->is_token_val( keyword => 'false' )) {
		my $value = $self->next_token->[1] eq 'true';
		$expression = { type => 'boolean_constant', value => $value };

	} elsif ($self->is_token_type('numeric_constant')) {
		my $value = $self->next_token->[1];
		$expression = { type => 'numeric_constant', value => $value };
		
	} elsif ($self->is_token_type('literal_string')) {
		my $value = $self->next_token->[1];
		if ($value =~ /^["']/) {
			die "invalid literal_string value $value" unless $value =~ s/^(["'])(.*)\1$/$2/s;
		} else {
			die "invalid literal_string value $value" unless $value =~ s/^\[(=*)\[(.*)\]\1\]$/$2/s;
		}
		$expression = { type => 'string_constant', value => $value };

	} elsif ($self->is_token_val( symbol => '...' )) {
		$self->next_token;
		$expression = { type => 'vararg_expression' };

	} elsif (($self->is_token_type('symbol') or $self->is_token_type('keyword')) and exists $snow_syntax_unary_operations_hash{$self->peek_token->[1]}) {
		my $operation = $self->next_token->[1];
		$expression = {
			type => 'unary_expression',
			operation => $operation,
			expression => $self->parse_syntax_expression,
		};
	} else {
		# $expression = $self->parse_syntax_prefix_expression;
		$self->confess_at_current_offset('expression expected');
	}

	# $expression = $self->parse_syntax_more_expression($expression);

	return $expression
}



1;


