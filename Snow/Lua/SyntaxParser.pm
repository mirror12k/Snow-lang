package Snow::Lua::SyntaxParser;
use parent 'Snow::Lua::TokenParser';
use strict;
use warnings;

use feature 'say';

use Carp;




sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);
	return $self;
}



sub parse {
	my ($self, $text) = @_;
	$self->SUPER::parse($text);

	$self->{syntax_tree} = $self->parse_syntax_block;
	$self->confess_at_current_offset('more tokens found after end of code') if $self->more_tokens;

	return $self->{syntax_tree}
}



sub parse_syntax_block {
	my ($self) = @_;

	my @block;
	while (my @statements = $self->parse_syntax_statements) {
		push @block, @statements;
	}
	my $statement = $self->parse_syntax_return_statement;
	push @block, $statement if defined $statement;


	return \@block
}



sub parse_syntax_statements {
	my ($self) = @_;

	return unless $self->more_tokens;

	my @statements;
	if ($self->is_token_val( symbol => '::' )) {
		$self->next_token;
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		$self->assert_step_token_val(symbol => '::');
		push @statements, { type => 'label_statement', identifier => $identifier };

	} elsif ($self->is_token_val( keyword => 'break' )) {
		$self->next_token;
		push @statements, { type => 'break_statement' };

	} elsif ($self->is_token_val( keyword => 'goto' )) {
		$self->next_token;
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		push @statements, { type => 'goto_statement', identifier => $identifier };

	} elsif ($self->is_token_val( keyword => 'do' )) {
		$self->next_token;
		push @statements, { type => 'block_statement', block => $self->parse_syntax_block };
		$self->assert_step_token_val(keyword => 'end');

	} elsif ($self->is_token_val( keyword => 'while' )) {
		$self->next_token;
		my $expression = $self->parse_syntax_expression;
		$self->assert_step_token_val(keyword => 'do');
		push @statements, { type => 'while_statement', expression => $expression, block => $self->parse_syntax_block };
		$self->assert_step_token_val(keyword => 'end');

	} elsif ($self->is_token_val( keyword => 'repeat' )) {
		$self->next_token;
		my $block = $self->parse_syntax_block;
		$self->assert_step_token_val(keyword => 'until');
		my $expression = $self->parse_syntax_expression;
		push @statements, { type => 'until_statement', expression => $expression, block => $block };

	} elsif ($self->is_token_val( keyword => 'if' )) {
		$self->next_token;
		my $expression = $self->parse_syntax_expression;
		$self->assert_step_token_val(keyword => 'then');

		my $branching_statement = { type => 'if_statement', expression => $expression, block => $self->parse_syntax_block };
		push @statements, $branching_statement;
		while ($self->is_token_val( keyword => 'elseif' )) {
			$self->next_token;
			$expression = $self->parse_syntax_expression;
			$self->assert_step_token_val(keyword => 'then');
			$branching_statement->{branch} = { type => 'elseif_statement', expression => $expression, block => $self->parse_syntax_block };
			$branching_statement = $branching_statement->{branch};
		}
		if ($self->is_token_val( keyword => 'else' )) {
			$self->next_token;
			$branching_statement->{branch} = { type => 'else_statement', block => $self->parse_syntax_block };
		}

		$self->assert_step_token_val(keyword => 'end');

	} elsif ($self->is_token_val( keyword => 'for' ) and $self->is_token_val( symbol => '=', 2 )) {
		$self->next_token;
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		$self->assert_step_token_val(symbol => '=');
		my $expression_start = $self->parse_syntax_expression;
		$self->assert_step_token_val(symbol => ',');
		my $expression_end = $self->parse_syntax_expression;
		my $expression_step;
		if ($self->is_token_val( symbol => ',' )) {
			$self->assert_step_token_val(symbol => ',');
			$expression_step = $self->parse_syntax_expression;
		} else {
			$expression_step = { type => 'numeric_constant', value => 1 };
		}
		$self->assert_step_token_val(keyword => 'do');
		push @statements, {
			type => 'for_statement',
			expression_start => $expression_start,
			expression_end => $expression_end,
			expression_step => $expression_step,
			block => $self->parse_syntax_block,
		};
		$self->assert_step_token_val(keyword => 'end');

	} elsif ($self->is_token_val( keyword => 'for' )) {
		$self->next_token;
		my $names_list = [ $self->parse_syntax_names_list ];
		$self->assert_step_token_val(keyword => 'in');
		my $expression_list = [ $self->parse_syntax_expression_list ];
		$self->assert_step_token_val(keyword => 'do');
		push @statements, {
			type => 'iter_statement',
			names_list => $names_list,
			expression_list => $expression_list,
			block => $self->parse_syntax_block,
		};
		$self->assert_step_token_val(keyword => 'end');

	} elsif ($self->is_token_val( keyword => 'function' )) {
		$self->next_token;
		my $identifier = { type => 'identifier_expression', identifier => $self->assert_step_token_type('identifier')->[1] };
		while ($self->is_token_val( symbol => '.' )) {
			$self->next_token;
			$identifier = { type => 'access_expression', expression => $identifier, identifier => $self->assert_step_token_type('identifier')->[1] };
		}
		my $has_self;
		if ($self->is_token_val( symbol => ':' )) {
			$self->next_token;
			$has_self = 1;
			$identifier = { type => 'access_expression', expression => $identifier, identifier => $self->assert_step_token_type('identifier')->[1] };
		}

		my $expression = $self->parse_syntax_function_expression;
		unshift @{$expression->{args_list}}, 'self' if $has_self;
		push @statements, {
			type => 'assignment_statement',
			var_list => [ $identifier ],
			expression_list => [ $expression ],
		};

	} elsif ($self->is_token_val( keyword => 'local' )) {
		$self->next_token;
		if ($self->is_token_val( keyword => 'function' )) {
			$self->next_token;
			my $identifier = $self->assert_step_token_type('identifier')->[1];
			push @statements, { type => 'variable_declaration_statement', names_list => [ $identifier ] };
			push @statements, { type => 'assignment_statement', var_list => [ $identifier ], expression_list => [ $self->parse_syntax_function_expression ] };
		} else {
			my $names_list = [ $self->parse_syntax_names_list ];
			my $expression_list;
			if ($self->is_token_val( symbol => '=' )) {
				$self->next_token;
				$expression_list = [ $self->parse_syntax_expression_list ];
			}
			push @statements, { type => 'variable_declaration_statement', names_list => $names_list, expression_list => $expression_list };
		}

	} elsif ($self->is_token_val( symbol => ';' )) {
		$self->next_token;
		push @statements, { type => 'empty_statement' };

	}

	return @statements
}

sub parse_syntax_return_statement {
	my ($self) = @_;
	

	return undef
}


sub parse_syntax_expression {
	my ($self) = @_;

	my $expression;
	if ($self->is_token_val( keyword => 'nil' )) {
		$self->next_token;
		$expression = { type => 'nil_constant' };

	} elsif ($self->is_token_val( keyword => 'true' ) or $self->is_token_val( keyword => 'false' )) {
		my $value = $self->next_token->[1] eq 'true';
		$expression = { type => 'bool_constant', value => $value };

	} elsif ($self->is_token_type('numeric_constant')) {
		my $value = $self->next_token->[1];
		$expression = { type => 'numeric_constant', value => $value };
		
	} elsif ($self->is_token_type('literal_string')) {
		my $value = $self->next_token->[1];
		if ($value =~ /^["']/) {
			die "invalid literal_string value $value" unless $value =~ s/^(["'])(.*)\1$/$1/s;
		} else {
			die "invalid literal_string value $value" unless $value =~ s/^\[(=*)\[(.*)\]\1\]$/$1/s;
		}
		$expression = { type => 'literal_string', value => $value };

	} elsif ($self->is_token_val( symbol => '...' )) {
		$self->next_token;
		$expression = { type => 'vararg_expression' };

	} else {
		$self->confess_at_current_offset('expression expected');
	}

	return $expression
}

sub parse_syntax_function_expression {
	my ($self) = @_;

	$self->assert_step_token_val(symbol => '(');
	my @args_list = $self->parse_syntax_args_list;
	$self->assert_step_token_val(symbol => ')');

	my $expression = {
		type => 'function_expression',
		args_list => \@args_list,
		block => $self->parse_syntax_block,
	};
	$self->assert_step_token_val(keyword => 'end');

	return $expression
}


sub parse_syntax_expression_list {
	my ($self) = @_;

	my @expression_list;
	push @expression_list, $self->parse_syntax_expression;

	while ($self->is_token_val( symbol => ',' )) {
		$self->next_token;
		push @expression_list, $self->parse_syntax_expression;
	}

	return @expression_list
}


sub parse_syntax_names_list {
	my ($self) = @_;

	my @names_list;
	push @names_list, $self->assert_step_token_type('identifier')->[1];

	while ($self->is_token_val( symbol => ',' )) {
		$self->next_token;
		push @names_list, $self->assert_step_token_type('identifier')->[1];
	}

	return @names_list
}


sub parse_syntax_args_list {
	my ($self) = @_;


	return $self->next_token->[1] if $self->is_token_val( symbol => '...' );

	my @args_list;
	push @args_list, $self->assert_step_token_type('identifier')->[1];

	while ($self->is_token_val( symbol => ',' )) {
		$self->next_token;
		if ($self->is_token_val( symbol => '...')) {
			push @args_list, $self->next_token->[1];
			last
		} else {
			push @args_list, $self->assert_step_token_type('identifier')->[1];
		}
	}

	say "got args_list: ", join ',', @args_list;

	return @args_list
}


# sub dump {
# 	my ($self) = @_;
# 	...
# }



1;

