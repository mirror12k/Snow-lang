package Snow::SyntaxTranslator;
use parent 'Snow::SyntaxParser';
use strict;
use warnings;

use feature 'say';

use Carp;
use Data::Dumper;




sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);

	$self->{snow_label_index} = 0;
	$self->{snow_last_label_stack} = [];
	$self->{snow_next_label_stack} = [];
	$self->{snow_redo_label_stack} = [];
	$self->{snow_last_label} = undef;
	$self->{snow_next_label} = undef;
	$self->{snow_redo_label} = undef;
	$self->{snow_last_label_usage_count} = undef;
	$self->{snow_next_label_usage_count} = undef;
	$self->{snow_redo_label_usage_count} = undef;

	return $self
}




sub parse {
	my ($self, $text) = @_;
	$self->SUPER::parse($text);

	$self->{globals_defined} = {
		print => '&',
		type => '&',
		tostring => '&',
		require => '&',
		select => '&',

		_G => '%',
		
		coroutine => '%',
		string => '%',
		table => '%',
		math => '%',
		debug => '%',
	};
	$self->{variables_stack} = [];
	$self->{variables_defined} = { %{$self->{globals_defined}} };

	$self->{syntax_tree} = [ $self->translate_syntax_block($self->{syntax_tree}) ];

	return $self->{syntax_tree}
}


sub new_snow_label {
	my ($self, $prefix) = @_;
	return "_snow_${prefix}__" . $self->{snow_label_index}++
}

sub push_snow_loop_labels {
	my ($self) = @_;
	push @{$self->{snow_last_label_stack}}, [ $self->{snow_last_label}, $self->{snow_last_label_usage_count} ];
	$self->{snow_last_label} = $self->new_snow_label('last');
	$self->{snow_last_label_usage_count} = 0;
	push @{$self->{snow_next_label_stack}}, [ $self->{snow_next_label}, $self->{snow_next_label_usage_count} ];
	$self->{snow_next_label} = $self->new_snow_label('next');
	$self->{snow_next_label_usage_count} = 0;
	push @{$self->{snow_redo_label_stack}}, [ $self->{snow_redo_label}, $self->{snow_redo_label_usage_count} ];
	$self->{snow_redo_label} = $self->new_snow_label('redo');
	$self->{snow_redo_label_usage_count} = 0;
}

sub pop_snow_loop_labels {
	my ($self) = @_;
	($self->{snow_last_label}, $self->{snow_last_label_usage_count}) = @{ pop @{$self->{snow_last_label_stack}} };
	($self->{snow_next_label}, $self->{snow_next_label_usage_count}) = @{ pop @{$self->{snow_next_label_stack}} };
	($self->{snow_redo_label}, $self->{snow_redo_label_usage_count}) = @{ pop @{$self->{snow_redo_label_stack}} };
}

sub register_globals {
	my ($self, @globals) = @_;
	foreach my $var (@globals) {
		my $type = substr $var, 0, 1;
		my $identifier = substr $var, 1;
		die "global redefined with conflicting type ($self->{globals_defined}{$identifier} vs $type)"
			if exists $self->{globals_defined}{$identifier} and $self->{globals_defined}{$identifier} ne $type;
		$self->{globals_defined}{$identifier} = $type;
		$self->{variables_defined}{$identifier} = $type;
	}
}

sub register_locals {
	my ($self, @locals) = @_;
	foreach my $var (@locals) {
		my $type = substr $var, 0, 1;
		my $identifier = substr $var, 1;
		$self->{variables_defined}{$identifier} = $type;
	}
}
sub exists_var {
	my ($self, $identifier) = @_;
	return 1 if exists $self->{variables_defined}{$identifier};
	foreach my $vars (reverse @{$self->{variables_stack}}) {
		return 1 if exists $vars->{$identifier};
	}
	return 0
}
sub get_var_type {
	my ($self, $identifier) = @_;
	return $self->{variables_defined}{$identifier} if exists $self->{variables_defined}{$identifier};
	foreach my $vars (reverse @{$self->{variables_stack}}) {
		return $vars->{$identifier} if exists $vars->{$identifier};
	}

	# warn Dumper $self->{variables_defined};
	# warn Dumper $self->{variables_stack};

	die "undefined variable referenced $identifier";
}


sub assert_sub_expression_type {
	my ($self, $type, $expression) = @_;
	die "attempt to use a '$expression->{var_type}' expression where a '$type' expression is required"
		unless $expression->{var_type} eq '*' or $expression->{var_type} eq $type;
}



sub translate_syntax_block {
	my ($self, $block, $scope_vars) = @_;

	push @{$self->{variables_stack}}, $self->{variables_defined};
	$self->{variables_defined} = $scope_vars // {};
	my @statements = map $self->translate_syntax_statement($_), @$block;
	$self->{variables_defined} = pop @{$self->{variables_stack}};
	return @statements
}



sub translate_syntax_statement {
	my ($self, $statement) = @_;

	if ($statement->{type} eq 'label_statement') {
		return $statement

	} elsif ($statement->{type} eq 'goto_statement') {
		return $statement

	} elsif ($statement->{type} eq 'break_statement') {
		return $statement

	} elsif ($statement->{type} eq 'last_statement') {
		die "last used outside of a loop" unless defined $self->{snow_last_label};
		$self->{snow_last_label_usage_count}++;
		return { type => 'goto_statement', identifier => $self->{snow_last_label} }

	} elsif ($statement->{type} eq 'next_statement') {
		die "next used outside of a loop" unless defined $self->{snow_next_label};
		$self->{snow_next_label_usage_count}++;
		return { type => 'goto_statement', identifier => $self->{snow_next_label} }

	} elsif ($statement->{type} eq 'redo_statement') {
		die "redo used outside of a loop" unless defined $self->{snow_redo_label};
		$self->{snow_redo_label_usage_count}++;
		return { type => 'goto_statement', identifier => $self->{snow_redo_label} }

	} elsif ($statement->{type} eq 'block_statement') {
		return { type => 'block_statement', block => [ $self->translate_syntax_block($statement->{block}) ] }

	} elsif ($statement->{type} eq 'if_statement') {
		return {
			type => 'if_statement',
			expression => $self->translate_syntax_expression($statement->{expression}),
			block => [ $self->translate_syntax_block($statement->{block}) ],
			branch => (defined $statement->{branch} ? $self->translate_syntax_statement($statement->{branch}) : undef),
		}
		
	} elsif ($statement->{type} eq 'elseif_statement') {
		return {
			type => 'elseif_statement',
			expression => $self->translate_syntax_expression($statement->{expression}),
			block => [ $self->translate_syntax_block($statement->{block}) ],
			branch => (defined $statement->{branch} ? $self->translate_syntax_statement($statement->{branch}) : undef),
		}

	} elsif ($statement->{type} eq 'else_statement') {
		return {
			type => 'else_statement',
			block => [ $self->translate_syntax_block($statement->{block}) ],
		}

	} elsif ($statement->{type} eq 'while_statement') {
		$self->push_snow_loop_labels;
		my @block = $self->translate_syntax_block($statement->{block});
		unshift @block, { type => 'label_statement', identifier => $self->{snow_redo_label} } if $self->{snow_redo_label_usage_count};
		push @block, { type => 'label_statement', identifier => $self->{snow_next_label} } if $self->{snow_next_label_usage_count};
		my @statements = ({
			type => 'while_statement',
			expression => $self->translate_syntax_expression($statement->{expression}),
			block => \@block,
		});
		if (defined $statement->{branch}) {
			push @statements, { type => 'block_statement', block => [ $self->translate_syntax_block($statement->{branch}{block}) ] }
		}
		push @statements, { type => 'label_statement', identifier => $self->{snow_last_label} } if $self->{snow_last_label_usage_count};
		$self->pop_snow_loop_labels;

		return @statements

	} elsif ($statement->{type} eq 'for_statement') {
		$self->push_snow_loop_labels;
		my @block = $self->translate_syntax_block($statement->{block}, { $statement->{identifier} => '#' });
		unshift @block, { type => 'label_statement', identifier => $self->{snow_redo_label} } if $self->{snow_redo_label_usage_count};
		push @block, { type => 'label_statement', identifier => $self->{snow_next_label} } if $self->{snow_next_label_usage_count};
		my @statements = ({
			type => 'for_statement',
			identifier => $statement->{identifier},
			expression_start => $self->translate_syntax_expression($statement->{start_expression}),
			expression_end => $self->translate_syntax_expression($statement->{end_expression}),
			expression_step => ( defined $statement->{step_expression} ? $self->translate_syntax_expression($statement->{step_expression}) : undef ),
			block => \@block,
		});
		if (defined $statement->{branch}) {
			push @statements, { type => 'block_statement', block => [ $self->translate_syntax_block($statement->{branch}{block}) ] }
		}
		push @statements, { type => 'label_statement', identifier => $self->{snow_last_label} } if $self->{snow_last_label_usage_count};
		$self->pop_snow_loop_labels;

		return @statements

	} elsif ($statement->{type} eq 'foreach_statement') {
		$self->push_snow_loop_labels;
		my $expression_type;
		$expression_type = $statement->{typehint} if defined $statement->{typehint};
		my $expression = $self->translate_syntax_expression($statement->{expression});
		$expression_type = $expression->{var_type} unless defined $expression_type;

		die "ambigious foreach expression" unless defined $expression_type;
		die "invalid var type in foreach expression: '$expression_type'" unless $expression_type eq '@' or $expression_type eq '%';

		my @block = $self->translate_syntax_block($statement->{block}, ($expression_type eq '@' ? { i => '#', v => '*' } : { k => '$', v => '*' }));
		unshift @block, { type => 'label_statement', identifier => $self->{snow_redo_label} } if $self->{snow_redo_label_usage_count};
		push @block, { type => 'label_statement', identifier => $self->{snow_next_label} } if $self->{snow_next_label_usage_count};
		my @statements = ({
			type => 'iter_statement',
			names_list => ($expression_type eq '@' ? [qw/ i v /] : [qw/ k v /]),
			expression_list => [{
				type => 'function_call_expression',
				expression => { type => 'identifier_expression', identifier => ($expression_type eq '@' ? 'ipairs' : 'pairs') },
				args_list => [ $expression ],
			}],
			block => \@block,
		});
		if (defined $statement->{branch}) {
			push @statements, { type => 'block_statement', block => [ $self->translate_syntax_block($statement->{branch}{block}) ] }
		}
		push @statements, { type => 'label_statement', identifier => $self->{snow_last_label} } if $self->{snow_last_label_usage_count};
		$self->pop_snow_loop_labels;

		return @statements

	} elsif ($statement->{type} eq 'variable_declaration_statement') {
		# TODO: verify assignment types
		$self->register_locals(@{$statement->{names_list}});
		return {
			type => 'variable_declaration_statement',
			names_list => [ map { substr $_, 1 } @{$statement->{names_list}} ],
			expression_list => ( defined $statement->{expression_list} ? [ $self->translate_syntax_expression_list($statement->{expression_list}) ] : undef ),
		}

	} elsif ($statement->{type} eq 'return_statement') {
		return {
			type => 'return_statement',
			expression_list => [ $self->translate_syntax_expression_list($statement->{expression_list}) ],
		}

	} elsif ($statement->{type} eq 'global_declaration_statement') {
		# TODO: verify assignment types
		$self->register_globals(@{$statement->{names_list}});
		return unless defined $statement->{expression_list};
		return {
			type => 'assignment_statement',
			var_list => [ map { { type => 'identifier_expression', identifier => substr $_, 1 } } @{$statement->{names_list}} ],
			expression_list => [ $self->translate_syntax_expression_list($statement->{expression_list}) ],
		}

	} elsif ($statement->{type} eq 'call_statement') {
		return {
			type => 'call_statement',
			expression => $self->translate_syntax_expression($statement->{expression}),
		}

	} elsif ($statement->{type} eq 'assignment_statement') {
		# TODO: verify assignment types
		my @var_list = $self->translate_syntax_expression_list($statement->{var_list});
		my @expression_list = $self->translate_syntax_expression_list($statement->{expression_list});
		if ($statement->{assignment_type} ne '=') {
			my $operation = $statement->{assignment_type} =~ s/^(.*)=$/$1/r;
			$operation = 'or' if $operation eq '?';
			foreach my $i (0 .. $#expression_list) {
				$expression_list[$i] = {
					type => 'binary_expression',
					operation => $operation,
					expression_left => $var_list[$i],
					expression_right => { type => 'parenthesis_expression', expression => $expression_list[$i] },
				}
			}
		}
		return {
			type => 'assignment_statement',
			var_list => \@var_list,
			expression_list => \@expression_list,
		}

	} elsif ($statement->{type} eq 'increment_statement') {
		my $expression = $self->translate_syntax_expression($statement->{expression});
		return {
			type => 'assignment_statement',
			var_list => [ $expression ],
			expression_list => [{
				type => 'binary_expression',
				operation => '+',
				expression_left => $expression,
				expression_right => { type => 'numeric_constant', value => 1 },
			}],
		}

	} elsif ($statement->{type} eq 'decrement_statement') {
		my $expression = $self->translate_syntax_expression($statement->{expression});
		return {
			type => 'assignment_statement',
			var_list => [ $expression ],
			expression_list => [{
				type => 'binary_expression',
				operation => '-',
				expression_left => $expression,
				expression_right => { type => 'numeric_constant', value => 1 },
			}],
		}

	} elsif ($statement->{type} eq 'function_declaration_statement') {
		my @pre_statements;
		if ($statement->{is_local}) {
			$self->register_locals("\&$statement->{identifier}");
			push @pre_statements, { type => 'variable_declaration_statement', names_list => [ $statement->{identifier} ] };
		} else {
			$self->register_globals("\&$statement->{identifier}") unless $self->exists_var($statement->{identifier});
		}
		return @pre_statements,
			{
			type => 'assignment_statement',
			var_list => [ { type => 'identifier_expression', identifier => $statement->{identifier} } ],
			expression_list => [ {
				type => 'function_expression',
				args_list => [ map { $_ eq '...' ? $_ : substr $_, 1 } @{$statement->{args_list}} ],
				block => [ $self->translate_syntax_block($statement->{block},
						{ map { substr ($_, 1) => substr ($_, 0, 1) } grep $_ ne '...', @{$statement->{args_list}} }) ],
			} ],
		}

	} else {
		die "unimplemented statement to translate: $statement->{type}";
	}

}


sub translate_syntax_expression {
	my ($self, $expression) = @_;


	if ($expression->{type} eq 'nil_constant') {
		return { type => 'nil_constant', value => $expression->{value}, var_type => '_' }

	} elsif ($expression->{type} eq 'boolean_constant') {
		return { type => 'boolean_constant', value => $expression->{value}, var_type => '?' }
		
	} elsif ($expression->{type} eq 'numeric_constant') {
		return { type => 'numeric_constant', value => $expression->{value}, var_type => '#' }
		
	} elsif ($expression->{type} eq 'string_constant') {
		# TODO: parse interpolation stuff
		return { type => 'string_constant', value => $expression->{value}, var_type => '$' }

	} elsif ($expression->{type} eq 'vararg_expression') {
		return { type => 'vararg_expression', var_type => '*' }

	} elsif ($expression->{type} eq 'parenthesis_expression') {
		my $sub_expression = $self->translate_syntax_expression($expression->{expression});
		return { type => 'parenthesis_expression', expression => $sub_expression, var_type => $sub_expression->{var_type} }

	} elsif ($expression->{type} eq 'unary_expression') {
		my $var_type;
		my $check_type;
		if ($expression->{operation} eq 'not') {
			$var_type = '?';
		} elsif ($expression->{operation} eq '#') {
			$var_type = '#';
			$check_type = '%';
		} elsif ($expression->{operation} eq '-') {
			$var_type = '#';
			$check_type = '#';
		} else {
			die "unimplemented unary expression operation: $expression->{operation}";
		}
		my $sub_expression = $self->translate_syntax_expression($expression->{expression});
		$self->assert_sub_expression_type($check_type => $sub_expression) if defined $check_type;
		return { type => 'unary_expression', operation => $expression->{operation}, expression => $sub_expression, var_type => $var_type }

	} elsif ($expression->{type} eq 'binary_expression') {
		my $var_type;
		my $check_type;
		if ($expression->{operation} eq '..') {
			$var_type = '$';
		} elsif ($expression->{operation} eq '+' or $expression->{operation} eq '-' or $expression->{operation} eq '*' or $expression->{operation} eq '/') {
			$var_type = '#';
		} elsif ($expression->{operation} eq 'or' or $expression->{operation} eq 'and') {
			$var_type = '?';
		} elsif ($expression->{operation} eq '==' or$expression->{operation} eq '~=' or $expression->{operation} eq '>'
				or $expression->{operation} eq '<' or $expression->{operation} eq '>=' or $expression->{operation} eq '<=') {
			$var_type = '?';
		} else {
			die "unimplemented binary expression operation: $expression->{operation}";
		}
		my $sub_expression_l = $self->translate_syntax_expression($expression->{expression_left});
		my $sub_expression_r = $self->translate_syntax_expression($expression->{expression_right});
		$self->assert_sub_expression_type($check_type => $sub_expression_l) if defined $check_type;
		$self->assert_sub_expression_type($check_type => $sub_expression_r) if defined $check_type;
		return {
			type => 'binary_expression',
			operation => $expression->{operation},
			expression_left => $sub_expression_l,
			expression_right => $sub_expression_r,
			var_type => $var_type
		}

	} elsif ($expression->{type} eq 'identifier_expression') {
		my $var_type = $self->get_var_type($expression->{identifier});
		return { type => 'identifier_expression', identifier => $expression->{identifier}, var_type => $var_type }
		
	} elsif ($expression->{type} eq 'access_expression') {
		my $sub_expression = $self->translate_syntax_expression($expression->{expression});
		return { type => 'access_expression', identifier => $expression->{identifier}, expression => $sub_expression, var_type => '*' }

	} elsif ($expression->{type} eq 'expressive_access_expression') {
		my $sub_expression = $self->translate_syntax_expression($expression->{expression});
		my $access_expression = $self->translate_syntax_expression($expression->{access_expression});
		return { type => 'expressive_access_expression', expression => $sub_expression, access_expression => $access_expression, var_type => '*' }
		
	} elsif ($expression->{type} eq 'function_call_expression') {
		my $sub_expression = $self->translate_syntax_expression($expression->{expression});
		$self->assert_sub_expression_type('&' => $sub_expression);
		return {
			type => 'function_call_expression',
			expression => $sub_expression,
			args_list => [ $self->translate_syntax_expression_list($expression->{args_list}) ],
			var_type => '*',
		}
		
	} elsif ($expression->{type} eq 'method_call_expression') {
		my $sub_expression = $self->translate_syntax_expression($expression->{expression});
		$self->assert_sub_expression_type('%' => $sub_expression);
		return {
			type => 'method_call_expression',
			identifier => $expression->{identifier},
			expression => $sub_expression,
			args_list => [ $self->translate_syntax_expression_list($expression->{args_list}) ],
			var_type => '*',
		}
		
	} elsif ($expression->{type} eq 'table_expression') {
		my $var_type = '*';
		if (@{$expression->{table_fields}}) {
			if ($expression->{table_fields}[0]{type} eq 'array_field') {
				$var_type = '@';
			} else {
				$var_type = '%';
			}
		}
		return {
			type => 'table_expression',
			table_fields => [ map $self->translate_syntax_table_field($_), @{$expression->{table_fields}} ],
			var_type => $var_type,
		}
		
	} elsif ($expression->{type} eq 'function_expression') {
		return {
			type => 'function_expression',
			args_list => [ map { $_ eq '...' ? $_ : substr $_, 1 } @{$expression->{args_list}} ],
				block => [ $self->translate_syntax_block($expression->{block},
						{ map { substr ($_, 1) => substr ($_, 0, 1) } grep $_ ne '...', @{$expression->{args_list}} }) ],
			var_type => '&',
		}

	} else {
		die "unimplemented expression in translation $expression->{type}";
	}
}

sub translate_syntax_expression_list {
	my ($self, $expression_list) = @_;

	return map $self->translate_syntax_expression($_), @$expression_list
}


sub translate_syntax_table_field {
	my ($self, $table_field) = @_;
	if ($table_field->{type} eq 'array_field') {
		return {
			type => 'array_field',
			expression => $self->translate_syntax_expression($table_field->{expression}),
		}
	} elsif ($table_field->{type} eq 'identifier_field') {
		return {
			type => 'identifier_field',
			identifier => $table_field->{identifier},
			expression => $self->translate_syntax_expression($table_field->{expression}),
		}
	} elsif ($table_field->{type} eq 'expressive_field') {
		return {
			type => 'expressive_field',
			key_expression => $self->translate_syntax_expression($table_field->{key_expression}),
			expression => $self->translate_syntax_expression($table_field->{expression}),
		}
	} else {
		die "unimplemented table field type $table_field->{type}";
	}
}



1;

