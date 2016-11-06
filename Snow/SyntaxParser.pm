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
	my $has_return = 0;
	# say "parse_syntax_block: '$whitespace_prefix'";
	while (my @statements = $self->parse_syntax_statements($whitespace_prefix)) {
		foreach my $statement (@statements) {
			die "statements found after return on line $line_number" if $has_return;
			$has_return = 1 if $statement->{type} eq 'return_statement';
		}
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

	my $index = $self->{tokens_index};
	# say "debug $index, '$whitespace_prefix'";
	if ($self->parse_syntax_whitespace($whitespace_prefix)) {
		# say "debug whitespace parsed";
		if ($self->is_token_val($type => $val)) {
			return 1
		} else {
			$self->{tokens_index} = $index;
			return 0
		}
	} else {
		$self->{tokens_index} = $index;
		return 0
	}
}


sub parse_syntax_string_constant {
	my ($self, $string) = @_;
	my $expression;
	while ($string =~ /^(.*?)\$($Snow::TokenParser::snow_identifier_regex)(.*)$/s) {
		if ($1 ne '') {
			my $sub_expression = { type => 'string_constant', value => $1 };
			$expression = defined $expression ? {
				type => 'binary_expression',
				operation => '..',
				expression_left => $expression,
				expression_right => $sub_expression,
			} : $sub_expression;
		}
		my $sub_expression = { type => 'identifier_expression', identifier => $2 };
		$expression = defined $expression ? {
			type => 'binary_expression',
			operation => '..',
			expression_left => $expression,
			expression_right => $sub_expression,
		} : $sub_expression;
		$string = $3;
	}
	if ($string ne '') {
		my $sub_expression = { type => 'string_constant', value => $string };
		$expression = defined $expression ? {
			type => 'binary_expression',
			operation => '..',
			expression_left => $expression,
			expression_right => $sub_expression,
		} : $sub_expression;
	} elsif (not defined $expression and $string eq '') {
		$expression = { type => 'string_constant', value => '' };
	}

	return $expression
}

sub assert_next_whitespace {
	my ($self, $msg) = @_;
	if ($self->more_tokens and not $self->is_token_type('whitespace')) {
		my ($type, $token) = @{$self->next_token};
		$self->confess_at_current_offset("expected whitespace after $msg, instead got $type token '$token'");
	}
}

sub assert_next_not_whitespace {
	my ($self, $expected, $msg) = @_;
	if ($self->is_token_type('whitespace')) {
		my ($type, $token) = @{$self->next_token};
		$self->confess_at_current_offset("expected $expected in $msg");
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
		$self->assert_next_not_whitespace(identifier => 'goto statement');
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		$self->assert_next_whitespace("goto statement");
		push @statements, { type => 'goto_statement', identifier => $identifier };

	} elsif ($self->is_token_val( keyword => 'break' )) {
		$self->next_token;
		$self->assert_next_whitespace("break statement");
		push @statements, { type => 'break_statement' };
	} elsif ($self->is_token_val( keyword => 'next' )) {
		$self->next_token;
		$self->assert_next_whitespace("next statement");
		push @statements, { type => 'next_statement' };
	} elsif ($self->is_token_val( keyword => 'redo' )) {
		$self->next_token;
		$self->assert_next_whitespace("redo statement");
		push @statements, { type => 'redo_statement' };
	} elsif ($self->is_token_val( keyword => 'last' )) {
		$self->next_token;
		$self->assert_next_whitespace("last statement");
		push @statements, { type => 'last_statement' };

	} elsif ($self->is_token_val( keyword => 'do' )) {
		$self->next_token;
		$self->assert_next_whitespace("do statement");
		push @statements, { type => 'block_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };

	} elsif ($self->is_token_val( keyword => 'while' ) or $self->is_token_val( keyword => 'until' )) {
		my $statement_type = $self->next_token->[1];
		my $invert = $statement_type eq 'until';
		$self->assert_next_not_whitespace(expression => "$statement_type statement");
		my $expression = $self->parse_syntax_expression;
		$expression = { type => 'unary_expression', operation => 'not', expression => { type => 'parenthesis_expression', expression => $expression } }
			if $invert;
		$self->assert_next_whitespace("$statement_type statement");
		my $statement = { type => 'while_statement', expression => $expression, block => $self->parse_syntax_block("$whitespace_prefix\t") };
		if ($self->is_far_next_token(keyword => 'else', $whitespace_prefix)) {
			$self->next_token;
			$self->assert_next_whitespace("else statement");
			$statement->{branch} = { type => 'else_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };
		}
		push @statements, $statement;

	} elsif ($self->is_token_val( keyword => 'for' )) {
		$self->next_token;
		$self->assert_next_not_whitespace('variable identifier' => "for statement");
		$self->assert_step_token_val( symbol => '#' );
		my $identifier = $self->assert_step_token_type( 'identifier' )->[1];
		$self->assert_step_token_val( symbol => '=' );
		my $start_expression = $self->parse_syntax_expression;
		$self->assert_step_token_val( symbol => ',' );
		my $end_expression = $self->parse_syntax_expression;
		my $step_expression;
		if ($self->is_token_val( symbol => ',' )) {
			$self->next_token;
			$step_expression = $self->parse_syntax_expression;
		}
		$self->assert_next_whitespace("for statement");
		my $statement = {
			type => 'for_statement',
			identifier => $identifier,
			start_expression => $start_expression,
			end_expression => $end_expression,
			step_expression => $step_expression,
			block => $self->parse_syntax_block("$whitespace_prefix\t"),
		};
		if ($self->is_far_next_token(keyword => 'else', $whitespace_prefix)) {
			$self->next_token;
			$self->assert_next_whitespace("else statement");
			$statement->{branch} = { type => 'else_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };
		}
		push @statements, $statement;

	} elsif ($self->is_token_val( keyword => 'foreach' )) {
		$self->next_token;
		$self->assert_next_not_whitespace(expression => "foreach statement");

		my $names_list;
		# unfortunately we must perform this complex look-ahead to see if it is a foreach-in statement or just a foreach statement
		if (
			($self->is_token_type('identifier') and ($self->is_token_val( symbol => ',', 1 ) or $self->is_token_val( keyword => 'in', 1 )))
			or (
				($self->is_token_val( symbol => '?' ) or $self->is_token_val( symbol => '#' ) or $self->is_token_val( symbol => '$' )
				or $self->is_token_val( symbol => '&' ) or $self->is_token_val( symbol => '@' ) or $self->is_token_val( symbol => '%' )
				or $self->is_token_val( symbol => '*' ))
				and $self->is_token_type('identifier', 1) and ($self->is_token_val( symbol => ',', 2 ) or $self->is_token_val( keyword => 'in', 2 ))
			)) {
			$names_list = [ $self->parse_syntax_names_list ];
			$self->assert_step_token_val( keyword => 'in' );
		}

		my $typehint;
		$typehint = $self->next_token->[1] if $self->is_token_val( symbol => '@' ) or $self->is_token_val( symbol => '%' );
		my $expression = $self->parse_syntax_expression;
		$self->assert_next_whitespace("foreach statement");
		my $statement = {
			type => 'foreach_statement',
			expression => $expression,
			typehint => $typehint,
			names_list => $names_list,
			block => $self->parse_syntax_block("$whitespace_prefix\t"),
		};
		if ($self->is_far_next_token(keyword => 'else', $whitespace_prefix)) {
			$self->next_token;
			$self->assert_next_whitespace("else statement");
			$statement->{branch} = { type => 'else_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };
		}
		push @statements, $statement;

	} elsif ($self->is_token_val( keyword => 'if' ) or $self->is_token_val( keyword => 'unless' )) {
		my $statement_type = $self->next_token->[1];
		$self->assert_next_not_whitespace(expression => "$statement_type statement");
		my $expression = $self->parse_syntax_expression;
		$expression = { type => 'unary_expression', operation => 'not', expression => { type => 'parenthesis_expression', expression => $expression } }
			if $statement_type eq 'unless';
		$self->assert_next_whitespace("$statement_type statement");
		my $statement = { type => 'if_statement', expression => $expression, block => $self->parse_syntax_block("$whitespace_prefix\t") };
		my $branch_statement = $statement;
		while ($self->is_far_next_token(keyword => 'elseif', $whitespace_prefix)) {
			$self->next_token;
			$self->assert_next_not_whitespace(expression => "elseif statement");
			$expression = $self->parse_syntax_expression;
			$self->assert_next_whitespace("elseif statement");
			$branch_statement->{branch} = { type => 'elseif_statement', expression => $expression, block => $self->parse_syntax_block("$whitespace_prefix\t") };
			$branch_statement = $branch_statement->{branch};
		}
		if ($self->is_far_next_token(keyword => 'else', $whitespace_prefix)) {
			$self->next_token;
			$self->assert_next_whitespace("else statement");
			$branch_statement->{branch} = { type => 'else_statement', block => $self->parse_syntax_block("$whitespace_prefix\t") };
		}
		push @statements, $statement;

	} elsif ($self->is_token_val( keyword => 'return' )) {
		$self->next_token;
		my $expression_list = [];
		$expression_list = [ $self->parse_syntax_expression_list ] if $self->more_tokens and not $self->is_token_type( 'whitespace' );

		$self->assert_next_whitespace("return statement");
		push @statements, {
			type => 'return_statement',
			expression_list => $expression_list,
		};

	} elsif ($self->is_token_val( keyword => 'function' ) or $self->is_token_val( keyword => 'method' )
			or ($self->is_token_val( keyword => 'local' ) and $self->is_token_val( keyword => 'function', 1 ))
			or ($self->is_token_val( keyword => 'local' ) and $self->is_token_val( keyword => 'method', 1 ))
		) {
		my $is_local = $self->is_token_val( keyword => 'local' );
		$self->next_token if $is_local;
		my $statement_type = $self->next_token->[1];
		$self->assert_next_not_whitespace(identifier => "$statement_type statement");
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		my $has_parenthesis = $self->is_token_val( symbol => '(' );
		$self->next_token if $has_parenthesis;
		my $args_list = $self->parse_syntax_args_list;
		my @initializations = grep ref $_, @$args_list;
		@$args_list = map { ref $_ ? $_->[0] : $_ } @$args_list;
		unshift @$args_list, "%self" if $statement_type eq 'method';
		$self->assert_step_token_val( symbol => ')' ) if $has_parenthesis;
		$self->assert_next_whitespace("$statement_type declaration statement");
		my $block = $self->parse_syntax_block("$whitespace_prefix\t");
		if (@initializations) {
			unshift @$block, {
				type => 'assignment_statement',
				assignment_type => '?=',
				var_list => [ map { type => 'identifier_expression', identifier => substr $_->[0], 1 }, @initializations ],
				expression_list => [ map $_->[1], @initializations ],
			};
		}
		push @statements, {
			type => 'function_declaration_statement',
			args_list => $args_list,
			identifier => $identifier,
			block => $block,
			is_local => $is_local,
		};
		

	} elsif ($self->is_token_val( keyword => 'local' )) {
		$self->next_token;
		$self->assert_next_not_whitespace(identifier => "local declaration statement");
		my $names_list = [ $self->parse_syntax_names_list ];
		my $expression_list;
		if ($self->is_token_val( symbol => '=' )) {
			$self->next_token;
			$expression_list = [ $self->parse_syntax_expression_list ];
		}

		$self->assert_next_whitespace("local declaration statement");
		push @statements, {
			type => 'variable_declaration_statement',
			names_list => $names_list,
			expression_list => $expression_list,
		};

	} elsif ($self->is_token_val( keyword => 'global' )) {
		$self->next_token;
		$self->assert_next_not_whitespace(identifier => "global declaration statement");
		my $names_list = [ $self->parse_syntax_names_list ];
		my $expression_list;
		if ($self->is_token_val( symbol => '=' )) {
			$self->next_token;
			$expression_list = [ $self->parse_syntax_expression_list ];
		}

		$self->assert_next_whitespace("global declaration statement");
		push @statements, {
			type => 'global_declaration_statement',
			names_list => $names_list,
			expression_list => $expression_list,
		};

	} elsif ($self->is_token_val( symbol => '++' )) {
		$self->next_token;
		$self->assert_next_not_whitespace(identifier => "increment statement");
		my $prefix_expression = $self->parse_syntax_prefix_expression;
		$self->assert_next_whitespace("increment statement");
		push @statements, { type => 'increment_statement', expression => $prefix_expression };

	} elsif ($self->is_token_val( symbol => '--' )) {
		$self->next_token;
		$self->assert_next_not_whitespace(decrement => "increment statement");
		my $prefix_expression = $self->parse_syntax_prefix_expression;
		$self->assert_next_whitespace("decrement statement");
		push @statements, { type => 'decrement_statement', expression => $prefix_expression };


	} elsif ($self->is_token_val( symbol => '(' ) or $self->is_token_type( 'identifier' )) {
		my $prefix_expression = $self->parse_syntax_prefix_expression;
		if ($prefix_expression->{type} eq 'function_call_expression' or $prefix_expression->{type} eq 'method_call_expression') {
			$self->assert_next_whitespace("call statement");
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
			if ($self->is_token_val( symbol => '+=' ) or $self->is_token_val( symbol => '-=' ) or $self->is_token_val( symbol => '*=' )
				or $self->is_token_val( symbol => '/=' ) or $self->is_token_val( symbol => '..=' ) or $self->is_token_val( symbol => '?=' )
				or $self->is_token_val( symbol => '=' )) {
				my $assignment_type = $self->next_token->[1];
				my $expression_list = [ $self->parse_syntax_expression_list ];
				if ($assignment_type ne '=' and @$expression_list != @var_list) {
					die "unequal number of variables and expressions for referencial assignment";
				}
				$self->assert_next_whitespace("assignment statement");
				push @statements, {
					type => 'assignment_statement',
					assignment_type => $assignment_type,
					var_list => \@var_list,
					expression_list => $expression_list,
				};
			} elsif ($self->is_token_val( symbol => '++' )) {
				$self->next_token;
				die "increment statement requires only one variable" unless @var_list == 1;
				$self->assert_next_whitespace("increment statement");
				push @statements, { type => 'increment_statement', expression => $var_list[0] };
			} elsif ($self->is_token_val( symbol => '--' )) {
				$self->next_token;
				die "decrement statement requires only one variable" unless @var_list == 1;
				$self->assert_next_whitespace("decrement statement");
				push @statements, { type => 'decrement_statement', expression => $var_list[0] };
			} else {
				$self->confess_at_current_offset("expected some assignment token ('=')");
			}
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
		$expression = $self->parse_syntax_string_constant($value);

	} elsif ($self->is_token_val( symbol => '{' )
		or $self->is_token_val( symbol => '?' ) or $self->is_token_val( symbol => '#' ) or $self->is_token_val( symbol => '$' )
		or $self->is_token_val( symbol => '&' ) or $self->is_token_val( symbol => '@' ) or $self->is_token_val( symbol => '%' )
		or $self->is_token_val( symbol => '*' ) or ($self->is_token_val( symbol => '...' ) and $self->is_token_val( symbol => '{', 1 ))) {
		my $function_expression = $self->parse_syntax_function_expression;
		return $function_expression

	} elsif ($self->is_token_val( symbol => '...' )) {
		$self->next_token;
		$expression = { type => 'vararg_expression' };

	} elsif ($self->is_token_val( symbol => '[' )) {
		$self->next_token;
		my $table_constructor = $self->parse_syntax_table_constructor;
		$self->assert_step_token_val( symbol => ']' );
		return $table_constructor

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

	$expression = $self->parse_syntax_more_expression($expression);

	return $expression
}



our @snow_syntax_binary_operations = qw#
	or
	and
	<
	>
	<=
	>=
	~=
	==
	|
	~
	&
	<<
	>>
	..
	+
	-
	*
	/
	//
	%
#;

our %snow_syntax_binary_operations_hash;
@snow_syntax_binary_operations_hash{@snow_syntax_binary_operations} = ();


sub parse_syntax_more_expression {
	my ($self, $expression) = @_;

	while (1) {
		if (($self->is_token_type('symbol') or $self->is_token_type('keyword')) and exists $snow_syntax_binary_operations_hash{$self->peek_token->[1]}) {
			# TODO: fix precedence
			my $operation = $self->next_token->[1];
			$expression = {
				type => 'binary_expression',
				operation => $operation,
				expression_left => $expression,
				expression_right => $self->parse_syntax_expression,
			};
		} else {
			return $expression
		}
	}
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
				or $self->is_token_type( 'literal_string' ) or $self->is_token_type( 'numeric_constant' ) or $self->is_token_type( 'identifier' )
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

	my $type;
	if ($self->is_token_val( symbol => '?' ) or $self->is_token_val( symbol => '#' ) or $self->is_token_val( symbol => '$' )
		or $self->is_token_val( symbol => '&' ) or $self->is_token_val( symbol => '@' ) or $self->is_token_val( symbol => '%' )
		or $self->is_token_val( symbol => '*' )) {
		$type = $self->next_token->[1];
	} else {
		$type = '*';
	}

	push @names_list, $type . $self->assert_step_token_type('identifier')->[1];

	while ($self->is_token_val( symbol => ',' )) {
		$self->next_token;
		$self->skip_whitespace_tokens;
		my $type;
		if ($self->is_token_val( symbol => '?' ) or $self->is_token_val( symbol => '#' ) or $self->is_token_val( symbol => '$' )
			or $self->is_token_val( symbol => '&' ) or $self->is_token_val( symbol => '@' ) or $self->is_token_val( symbol => '%' )
			or $self->is_token_val( symbol => '*' )) {
			$type = $self->next_token->[1];
		} else {
			$type = '*';
		}
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
		if ( $self->is_token_type( 'literal_string' ) or $self->is_token_type( 'numeric_constant' ) or $self->is_token_type( 'identifier' )
				or $self->is_token_val( symbol => '[' ) or $self->is_token_val( symbol => '{' ) or $self->is_token_val( symbol => '...' )
				or $self->is_token_val( keyword => 'nil' ) or $self->is_token_val( keyword => 'true' ) or $self->is_token_val( keyword => 'false' )
				or $self->is_token_val( keyword => ':' ) or $self->is_token_val( symbol => '...' )
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

sub parse_syntax_table_constructor {
	my ($self) = @_;

	my $is_assoc_table;
	my @table_fields;
	$self->skip_whitespace_tokens;
	until ($self->is_token_val( symbol => ']' )) {
		my $expression = $self->parse_syntax_expression;
		$is_assoc_table = $is_assoc_table // $self->is_token_val( symbol => '=>' );
		if ($is_assoc_table) {
			$self->assert_step_token_val( symbol => '=>' );
			my $val_expression = $self->parse_syntax_expression;

			if ($expression->{type} eq 'identifier_expression') {
				push @table_fields, { type => 'identifier_field', identifier => $expression->{identifier}, expression => $val_expression };
			} else {
				push @table_fields, { type => 'expressive_field', key_expression => $expression, expression => $val_expression };
			}
		} else {
			push @table_fields, { type => 'array_field', expression => $expression };
		}

		if ($self->is_token_val( symbol => ',' )) {
			$self->next_token;
		} else {
			last
		}
		$self->skip_whitespace_tokens;
	}
	$self->skip_whitespace_tokens;

	return {
		type => 'table_expression',
		table_fields => \@table_fields,
	}
}


my %snow_syntax_default_variable_identifiers = (
	'?' => 'b',
	'#' => 'n',
	'$' => 's',
	'@' => 'a',
	'%' => 't',
	'&' => 'f',
	'*' => 'x',
);

sub parse_syntax_args_list {
	my ($self) = @_;

	my @args_list;
	my %var_map;

	my $is_named;
	while (
			$self->is_token_val(symbol => '?') or $self->is_token_val(symbol => '#') or $self->is_token_val(symbol => '$')
			or $self->is_token_val(symbol => '@') or $self->is_token_val(symbol => '%') or $self->is_token_val(symbol => '&') or $self->is_token_val(symbol => '*')
			or $self->is_token_type('identifier') or $self->is_token_val( symbol => '...' )
		) {

		if ($self->is_token_val( symbol => '...' )) {
			$self->next_token;
			push @args_list, '...';
			return \@args_list
		}

		my $arg;

		my $type;
		my $identifier;
		if ($self->is_token_type('identifier')) {
			$is_named = 1 unless defined $is_named;
			die "attempt to mix named and default function arguments" if $is_named == 0;
			$type = '*';
		} else {
			$type = $self->next_token->[1];
		}

		if ($self->is_token_type('identifier')) {
			$is_named = 1 unless defined $is_named;
			die "attempt to mix named and default function arguments" if $is_named == 0;
			$identifier = $self->next_token->[1];

			$arg = "$type$identifier";
			if ($self->is_token_val( symbol => '=' )) {
				$self->next_token;
				my $init_expression = $self->parse_syntax_expression;
				$arg = [ $arg => $init_expression ];
			}
			if ($self->is_token_val( symbol => ',' )) {
				$self->next_token;
			} else {
				push @args_list, $arg;
				last;
			}
		} else {
			$is_named = 0 unless defined $is_named;
			die "attempt to mix named and default function arguments" if $is_named == 1;

			unless (defined $var_map{$type}) {
				$var_map{$type} = 1;
				$identifier = $snow_syntax_default_variable_identifiers{$type};
			} else {
				if ($var_map{$type} == 1) {
					my $search = "$type$snow_syntax_default_variable_identifiers{$type}";
					@args_list = map { $_ eq $search ? "${_}1" : $_ } @args_list;
				}
				$var_map{$type}++;
				$identifier = "$snow_syntax_default_variable_identifiers{$type}$var_map{$type}";
			}
			$arg = "$type$identifier";
		}

		push @args_list, $arg
	}

	return \@args_list
}



sub parse_syntax_function_expression {
	my ($self) = @_;

	my $args_list = [];
	if ($self->is_token_val( symbol => '?' ) or $self->is_token_val( symbol => '#' ) or $self->is_token_val( symbol => '$' )
		or $self->is_token_val( symbol => '&' ) or $self->is_token_val( symbol => '@' ) or $self->is_token_val( symbol => '%' )
		or $self->is_token_val( symbol => '*' ) or $self->is_token_val( symbol => '...' )) {
		$args_list = $self->parse_syntax_args_list;
	}

	$self->assert_step_token_val( symbol => '{' );
	my $block = [];
	if ($self->is_token_type( 'whitespace' )) {
		my $prefix = $self->peek_token->[1] =~ s/^.*\n([^\n]*)$/$1/rs;
		$block = $self->parse_syntax_block($prefix);
	} elsif ($self->is_token_val( symbol => '}' )) {
		# do nothing
	} else {
		my $expression_list = [ $self->parse_syntax_expression_list ];

		push @$block, {
			type => 'return_statement',
			expression_list => $expression_list,
		};
	}
	$self->skip_whitespace_tokens;
	$self->assert_step_token_val( symbol => '}' );

	my @initializations = grep ref $_, @$args_list;
	@$args_list = map { ref $_ ? $_->[0] : $_ } @$args_list;
	if (@initializations) {
		unshift @$block, {
			type => 'assignment_statement',
			assignment_type => '?=',
			var_list => [ map { type => 'identifier_expression', identifier => substr $_->[0], 1 }, @initializations ],
			expression_list => [ map $_->[1], @initializations ],
		};
	}
	
	return {
		type => 'function_expression',
		args_list => $args_list,
		block => $block,
	}
}



1;


