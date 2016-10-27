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
	# say "parse_syntax_block: '$whitespace_prefix'";
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

	return 0 unless $self->more_tokens;

	while ($self->is_token_type( 'whitespace' )) {
		my $prefix = $self->peek_token->[1] =~ s/^.*\n([^\n]*)$/$1/rs;
		# say "got prefix: '$prefix'";
		if (($self->more_tokens(1) and $self->is_token_type( 'whitespace', 1 )) or $prefix =~ /^$whitespace_prefix/) {
			# say "skipping whitespace";
			$self->next_token;
			return 1 unless $self->is_token_type( 'whitespace' );
		} else {
			# say "whitespace end";
			return 0
		}
	}
}

sub skip_whitespace_tokens {
	my ($self) = @_;
	while ($self->is_token_type( 'whitespace' )) {
		$self->next_token;
	}
}

# if the next token is on appropriate whitespace positioning and matches
sub is_far_next_token {
	my ($self, $type, $val, $whitespace_prefix) = @_;

	my $index = $self->{code_tokens_index};
	# say "debug $index, '$whitespace_prefix'";
	if ($self->parse_syntax_whitespace($whitespace_prefix)) {
		# say "debug whitespace parsed";
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

	# say "debug parse_syntax_statements '$whitespace_prefix'";

	return unless $self->parse_syntax_whitespace($whitespace_prefix);

	my @statements;
	if ($self->is_token_type( 'identifier' ) and $self->is_token_val( symbol => ':', 1 ) and $self->is_token_type( whitespace => 2 )) {
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

	} elsif ($self->is_token_val( keyword => 'while' ) or $self->is_token_val( keyword => 'until' )) {
		my $invert = $self->next_token->[1] eq 'until';
		my $expression = $self->parse_syntax_expression;
		$expression = { type => 'unary_expression', operation => 'not', expression => { type => 'parenthesis_expression', expression => $expression } }
			if $invert;
		my $statement = { type => 'while_statement', expression => $expression, block => $self->parse_syntax_block("$whitespace_prefix\t") };
		if ($self->is_far_next_token(keyword => 'else', $whitespace_prefix)) {
			$self->next_token;
			$statement->{branch} = { type => 'else_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };
		}
		push @statements, $statement;

	} elsif ($self->is_token_val( keyword => 'if' ) or $self->is_token_val( keyword => 'unless' )) {
		my $invert = $self->next_token->[1] eq 'unless';
		my $expression = $self->parse_syntax_expression;
		$expression = { type => 'unary_expression', operation => 'not', expression => { type => 'parenthesis_expression', expression => $expression } }
			if $invert;
		my $statement = { type => 'if_statement', expression => $expression, block => $self->parse_syntax_block("$whitespace_prefix\t") };
		my $branch_statement = $statement;
		while ($self->is_far_next_token(keyword => 'elseif', $whitespace_prefix)) {
			$self->next_token;
			$expression = $self->parse_syntax_expression;
			$branch_statement->{branch} = { type => 'elseif_statement', expression => $expression, block => $self->parse_syntax_block("$whitespace_prefix\t") };
			$branch_statement = $branch_statement->{branch};
		}
		if ($self->is_far_next_token(keyword => 'else', $whitespace_prefix)) {
			$self->next_token;
			$branch_statement->{branch} = { type => 'else_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };
		}
		push @statements, $statement;

	} elsif ($self->is_token_val( keyword => 'local' )) {
		$self->next_token;
		my $names_list = [ $self->parse_syntax_names_list ];
		my $expression_list;
		if ($self->is_token_val( symbol => '=' )) {
			$self->next_token;
			$expression_list = [ $self->parse_syntax_expression_list ];
		}

		push @statements, {
			type => 'variable_declaration_statement',
			names_list => $names_list,
			expression_list => $expression_list,
		};

	} elsif ($self->is_token_val( keyword => 'global' )) {
		$self->next_token;
		my $names_list = [ $self->parse_syntax_names_list ];
		my $expression_list;
		if ($self->is_token_val( symbol => '=' )) {
			$self->next_token;
			$expression_list = [ $self->parse_syntax_expression_list ];
		}

		push @statements, {
			type => 'global_declaration_statement',
			names_list => $names_list,
			expression_list => $expression_list,
		};

	} elsif ($self->is_token_val( symbol => '(' ) or $self->is_token_type( 'identifier' )) {
		my $prefix_expression = $self->parse_syntax_prefix_expression;
		if ($prefix_expression->{type} eq 'function_call_expression' or $prefix_expression->{type} eq 'method_call_expression') {
			push @statements, { type => 'call_statement', expression => $prefix_expression };
		} elsif ($prefix_expression->{type} eq 'identifier_expression' or $prefix_expression->{type} eq 'access_expression'
				or $prefix_expression->{type} eq 'expressive_access_expression') {
			my @var_list = ($prefix_expression);
			while ($self->is_token_val( symbol => ',' )) {
				$self->next_token;
				$self->skip_whitespace_tokens;
				$prefix_expression = $self->parse_syntax_prefix_expression;
				$self->confess_at_current_offset("invalid varlist prefix expression $prefix_expression->{type}")
						unless $prefix_expression->{type} eq 'identifier_expression' or $prefix_expression->{type} eq 'access_expression'
						or $prefix_expression->{type} eq 'expressive_access_expression';
				push @var_list, $prefix_expression;
			}
			$self->assert_step_token_val( symbol => '=' );
			push @statements, { type => 'assignment_statement', var_list => \@var_list, expression_list => [ $self->parse_syntax_expression_list ] };
		} else {
			$self->confess_at_current_offset("unexpected prefix expression '$prefix_expression->{type}' (function call or variable assignment exected)");
		}
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
		$expression = $self->parse_syntax_prefix_expression;
		# $self->confess_at_current_offset('expression expected');
	}

	# $expression = $self->parse_syntax_more_expression($expression);

	return $expression
}



sub parse_syntax_prefix_expression {
	my ($self) = @_;

	my $expression;

	if ($self->is_token_val( symbol => '(' )) {
		$self->next_token;
		$expression = { type => 'parenthesis_expression', expression => $self->parse_syntax_expression };
		$self->assert_step_token_val( symbol => ')' );
	} elsif ($self->is_token_type( 'identifier' )) {
		my $identifier = $self->next_token->[1];
		$expression = { type => 'identifier_expression', identifier => $identifier };
	} else {
		say $self->dump_at_current_offset;
		$self->confess_at_current_offset('invalid prefix expression');
	}

	while (1) {
		# say "debug: ", join ', ', $self->is_token_val( symbol => ':' ), $self->is_token_type( 'identifier', 1 );
		if ($self->is_token_val( symbol => '.' )) {
			$self->next_token;
			my $identifier = $self->assert_step_token_type('identifier')->[1];
			$expression = { type => 'access_expression', expression => $expression, identifier => $identifier };

		} elsif ($self->is_token_val( symbol => '[' )) {
			$self->next_token;
			$expression = { type => 'expressive_access_expression', expression => $expression, access_expression => $self->parse_syntax_expression };
			$self->assert_step_token_val( symbol => ']' );

		} elsif ($self->is_token_val( symbol => ':' ) and $self->is_token_type( 'identifier', 1 )) {
			$self->next_token;
			my $identifier = $self->next_token->[1];
			my $args_list = [ $self->parse_syntax_function_args_list ];
			$expression = { type => 'method_call_expression', identifier => $identifier, expression => $expression, args_list => $args_list };

		} elsif ($self->is_token_val( symbol => '(' )
				or $self->is_token_type( 'literal_string' ) or $self->is_token_type( 'numeric_constant' )
				or $self->is_token_val( symbol => '{' ) or $self->is_token_val( symbol => '...' )
				or $self->is_token_val( keyword => 'nil' ) or $self->is_token_val( keyword => 'true' ) or $self->is_token_val( keyword => 'false' )
				or $self->is_token_val( keyword => ':' )
			) {
			my $args_list = [ $self->parse_syntax_function_args_list ];
			$expression = { type => 'function_call_expression', expression => $expression, args_list => $args_list };

		} else {
			return $expression;
		}
	}
}

sub parse_syntax_names_list {
	my ($self) = @_;

	my @names_list;

	$self->confess_at_current_offset("variable type expected") unless
		$self->is_token_val( symbol => '?' )
		or $self->is_token_val( symbol => '#' )
		or $self->is_token_val( symbol => '$' )
		or $self->is_token_val( symbol => '&' )
		or $self->is_token_val( symbol => '@' )
		or $self->is_token_val( symbol => '%' )
		or $self->is_token_val( symbol => '*' );
	my $type = $self->next_token->[1];
	push @names_list, $type . $self->assert_step_token_type('identifier')->[1];

	while ($self->is_token_val( symbol => ',' )) {
		$self->next_token;
		$self->skip_whitespace_tokens;
		$self->confess_at_current_offset("variable type expected") unless
			$self->is_token_val( symbol => '?' )
			or $self->is_token_val( symbol => '#' )
			or $self->is_token_val( symbol => '$' )
			or $self->is_token_val( symbol => '&' )
			or $self->is_token_val( symbol => '@' )
			or $self->is_token_val( symbol => '%' )
			or $self->is_token_val( symbol => '*' );
		my $type = $self->next_token->[1];
		push @names_list, $type . $self->assert_step_token_type('identifier')->[1];
	}

	return @names_list
}


sub parse_syntax_function_args_list {
	my ($self) = @_;
	my @args_list;
	if ($self->is_token_val( symbol => '(' )) {
		$self->next_token;
		@args_list = $self->parse_syntax_expression_list unless $self->is_token_val( symbol => ')' );
		$self->assert_step_token_val( symbol => ')' );
	} else {
		if ( $self->is_token_type( 'literal_string' ) or $self->is_token_type( 'numeric_constant' )
				or $self->is_token_val( symbol => '{' ) or $self->is_token_val( symbol => '...' )
				or $self->is_token_val( keyword => 'nil' ) or $self->is_token_val( keyword => 'true' ) or $self->is_token_val( keyword => 'false' )
				or $self->is_token_val( keyword => ':' )
			) {
			@args_list = $self->parse_syntax_expression_list;
		}
	}

	return @args_list
}

sub parse_syntax_expression_list {
	my ($self) = @_;

	my @expression_list;
	push @expression_list, $self->parse_syntax_expression;

	while ($self->is_token_val( symbol => ',' )) {
		$self->next_token;
		$self->skip_whitespace_tokens;
		push @expression_list, $self->parse_syntax_expression;
	}

	return @expression_list
}


1;


