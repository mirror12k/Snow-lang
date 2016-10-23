package Snow::Lua::Bytecode;
use parent 'Snow::Lua::SyntaxParser';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;
use Carp;
use List::Util 'any';



our $lua_nil_constant = [ nil => 'nil' ];



sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);
	return $self;
}



sub parse {
	my ($self, $text) = @_;
	$self->SUPER::parse($text);

	$self->{bytecode_chunk} = { chunk => $self->{syntax_tree}, closure_list => [], closure_map => {}, sourcefile => $self->{filepath} };
	$self->{bytecode_chunk_queue} = [ $self->{bytecode_chunk} ];

	while (@{$self->{bytecode_chunk_queue}}) {
		my $chunk_record = shift @{$self->{bytecode_chunk_queue}};
		$self->parse_bytecode_chunk_record($chunk_record);
	}
	return $self->{bytecode_chunk}
}

sub parse_bytecode_chunk_record {
	my ($self, $chunk) = @_;

	$self->{current_chunk} = $chunk;

	$self->{local_scope_stack} = [];
	$self->{current_local_scope} = undef;
	$self->{current_local_index} = 0;

	$self->{local_label_stack} = [];
	$self->{current_local_labels} = undef;
	$self->{current_break_label} = undef;
	$self->{line_number_table} = [];

	$self->{current_jump_index} = 0;

	$self->{is_vararg_chunk} = (defined $chunk->{args_list} and @{$chunk->{args_list}} > 0 and $chunk->{args_list}[-1] eq '...');

	my $args_list = $chunk->{args_list};
	$args_list = [ grep $_ !~ /^\.\.\.$/, @$args_list ] if $self->{is_vararg_chunk};


	if (defined $args_list) {
		$self->{current_local_scope}{$_} = $self->{current_local_index}++ foreach @$args_list;
	}

	my @block = $self->parse_bytecode_block($chunk->{chunk});
	# warn "dump bytecode labels:\n", $self->dump_bytecode(\@block); # DEBUG BYTECODE
	my @bytecode = $self->resolve_bytecode_labels(@block);
	unshift @bytecode, es => undef;
	if (defined $args_list and @$args_list > 0) {
		unshift @bytecode, 
			ts => scalar @$args_list,
			yl => 0,
		;
	}
	unshift @bytecode, sv => scalar @$args_list if $self->{is_vararg_chunk};
	unshift @bytecode, xl => $self->{current_local_index} if $self->{current_local_index} > 0;
	# warn "opcode count $#bytecode"; # DEBUG BYTECODE
	# warn "dump bytecode:\n", $self->dump_bytecode(\@bytecode); # DEBUG BYTECODE
	# warn "line numbers:\n", Dumper $self->{line_number_table}; # DEBUG BYTECODE

	$chunk->{line_number_table} = $self->{line_number_table};
	$chunk->{chunk} = [ @bytecode ];
}

sub parse_bytecode_block {
	my ($self, $block) = @_;

	push @{$self->{local_scope_stack}}, $self->{current_local_scope} if defined $self->{current_local_scope};
	$self->{current_local_scope} = {};
	push @{$self->{local_label_stack}}, $self->{current_local_labels} if defined $self->{current_local_labels};
	$self->{current_local_labels} = {};


	# run through once to collect all local labels
	foreach my $statement (@$block) {
		if ($statement->{type} eq 'label_statement') {
			$self->{current_local_labels}{$statement->{identifier}} = "user_label_" . $self->{current_jump_index}++;
		}
	}

	my @bytecode;
	foreach my $statement (@$block) {
		push @bytecode, _line_number => $statement->{line_number};

		if ($statement->{type} eq 'empty_statement') {
			# nothing
		} elsif ($statement->{type} eq 'label_statement') {
			push @bytecode, _label => $self->{current_local_labels}{$statement->{identifier}};
		} elsif ($statement->{type} eq 'goto_statement') {
			push @bytecode, aj => $self->parse_bytecode_user_label($statement->{identifier});
		} elsif ($statement->{type} eq 'break_statement') {
			die "break used outside of a breakable location" unless defined $self->{current_break_label};
			push @bytecode, aj => $self->{current_break_label};
		} elsif ($statement->{type} eq 'block_statement') {
			push @bytecode, $self->parse_bytecode_block($statement->{block});
		} elsif ($statement->{type} eq 'variable_declaration_statement') {
			$self->{current_local_scope}{$_} = $self->{current_local_index}++ foreach @{$statement->{names_list}};
			if (defined $statement->{expression_list}) {
				push @bytecode,
					$self->parse_bytecode_expression_list($statement->{expression_list}),
					ts => scalar @{$statement->{names_list}},
					yl => $self->{current_local_scope}{$statement->{names_list}[0]},
					es => undef,
			}
		} elsif ($statement->{type} eq 'assignment_statement') {
			push @bytecode,
				$self->parse_bytecode_expression_list($statement->{expression_list}),
				rs => undef,
				( map $self->parse_bytecode_lvalue_expression($_), @{$statement->{var_list}} ),
				es => undef,
		} elsif ($statement->{type} eq 'call_statement') {
			push @bytecode,
				$self->parse_bytecode_expression(multi => $statement->{expression}),
				es => undef,
		} elsif ($statement->{type} eq 'until_statement') {
			# TODO support local variable application in the expression part (WHY lua???)
			my $repeat_label = "repeat_" . $self->{current_jump_index}++;
			my $end_label = "repeat_end_" . $self->{current_jump_index}++;
			my $last_break_label = $self->{current_break_label};
			$self->{current_break_label} = $end_label;
			push @bytecode,
				_label => $repeat_label,
				$self->parse_bytecode_block($statement->{block}),
				$self->parse_bytecode_expression(single => $statement->{expression}),
				bt => undef,
				fj => $repeat_label,
				_label => $end_label,
			;
			$self->{current_break_label} = $last_break_label;
		} elsif ($statement->{type} eq 'while_statement') {
			my $expression_label = "while_" . $self->{current_jump_index}++;
			my $end_label = "while_end_" . $self->{current_jump_index}++;
			my $last_break_label = $self->{current_break_label};
			$self->{current_break_label} = $end_label;
			push @bytecode,
				_label => $expression_label,
				$self->parse_bytecode_expression(single => $statement->{expression}),
				bt => undef,
				fj => $end_label,
				$self->parse_bytecode_block($statement->{block}),
				aj => $expression_label,
				_label => $end_label,
			;
			$self->{current_break_label} = $last_break_label;
		} elsif ($statement->{type} eq 'for_statement') {
			my $iter_var = $self->{current_local_index}++;
			$self->{current_local_scope}{$statement->{identifier}} = $iter_var;
			my $expression_label = "for_" . $self->{current_jump_index}++;
			my $end_label = "for_end_" . $self->{current_jump_index}++;
			my $last_break_label = $self->{current_break_label};
			$self->{current_break_label} = $end_label;
			push @bytecode,
				$self->parse_bytecode_expression(single => $statement->{expression_start}),
				# TODO: cast number on these values
				sl => $iter_var,
				$self->parse_bytecode_expression(single => $statement->{expression_end}),
				$self->parse_bytecode_expression(single => $statement->{expression_step}),
				_label => $expression_label,
				fr => $iter_var,
				fj => $end_label,
				ss => undef,
				$self->parse_bytecode_block($statement->{block}),
				ms => undef,
				bs => undef,
				ll => $iter_var,
				bn => '+',
				sl => $iter_var,
				aj => $expression_label,
				_label => $end_label,
				es => undef,
			;
			$self->{current_break_label} = $last_break_label;
		} elsif ($statement->{type} eq 'iter_statement') {
			$self->{current_local_scope}{$_} = $self->{current_local_index}++ foreach @{$statement->{names_list}};
			my $expression_label = "iter_" . $self->{current_jump_index}++;
			my $end_label = "iter_end_" . $self->{current_jump_index}++;
			my $last_break_label = $self->{current_break_label};
			$self->{current_break_label} = $end_label;
			push @bytecode,
				$self->parse_bytecode_expression_list($statement->{expression_list}),
				ts => 3,
				sl => $self->{current_local_scope}{$statement->{names_list}[0]},
				_label => $expression_label,
				cs => undef,
				ll => $self->{current_local_scope}{$statement->{names_list}[0]},
				cf => undef,
				ts => scalar @{$statement->{names_list}},
				yl => $self->{current_local_scope}{$statement->{names_list}[0]},
				ds => undef,
				ll => $self->{current_local_scope}{$statement->{names_list}[0]},
				bt => undef,
				fj => $end_label,
				ss => undef,
				$self->parse_bytecode_block($statement->{block}),
				ms => undef,
				aj => $expression_label,
				_label => $end_label,
				es => undef,
			;
			$self->{current_break_label} = $last_break_label;
		} elsif ($statement->{type} eq 'if_statement') {
			my $branch_label = "branch_" . $self->{current_jump_index}++;
			push @bytecode,
				$self->parse_bytecode_expression(single => $statement->{expression}),
				bt => undef,
				fj => $branch_label,
				$self->parse_bytecode_block($statement->{block}),
			;

			if (defined $statement->{branch}) {
				my $end_label = "end_" . $self->{current_jump_index}++;
				my $branch_statement = $statement->{branch};
				while (defined $branch_statement) {
					push @bytecode, aj => $end_label;
					push @bytecode, _label => $branch_label;
					$branch_label = "branch_" . $self->{current_jump_index}++;
					push @bytecode, 
						$self->parse_bytecode_expression(single => $branch_statement->{expression}),
						bt => undef,
						fj => $branch_label,
						if $branch_statement->{type} eq 'elseif_statement';
					push @bytecode, $self->parse_bytecode_block($branch_statement->{block});
					$branch_statement = $branch_statement->{branch};
				}
				push @bytecode, _label => $end_label;
			}

			push @bytecode, _label => $branch_label;

		} elsif ($statement->{type} eq 'return_statement') {
			push @bytecode,
				$self->parse_bytecode_expression_list($statement->{expression_list}),
				lf => undef,
		} else {
			die "unimplemented statement type $statement->{type}";
		}
	}

	# say Dumper $self->{current_local_scope};
	$self->{current_local_scope} = shift @{$self->{local_scope_stack}} if @{$self->{local_scope_stack}};
	$self->{current_local_labels} = shift @{$self->{local_label_stack}} if @{$self->{local_label_stack}};

	return @bytecode
}

sub resolve_bytecode_labels {
	my ($self, @block) = @_;

	my @bytecode;
	my %labels;

	while (@block) {
		my $op = shift @block;
		my $arg = shift @block;

		if ($op eq '_label') {
			$labels{$arg} = scalar @bytecode;
		} elsif ($op eq '_line_number') {
			push @{$self->{line_number_table}}, scalar (@bytecode) => $arg
				unless @{$self->{line_number_table}} and $self->{line_number_table}[-2] == scalar (@bytecode);
		} else {
			push @bytecode, $op => $arg;
		}
	}

	my $i = 0;
	while ($i < @bytecode) {
		my $op = $bytecode[$i++];
		my $arg = $bytecode[$i++];

		if ($op eq 'aj' or $op eq 'fj' or $op eq 'tj') {
			die "missing label '$arg' while resolving" unless exists $labels{$arg};
			$bytecode[$i - 1] = $labels{$arg} - $i;
		}
	}

	return @bytecode
}



sub parse_bytecode_expression_list {
	my ($self, $expression_list) = @_;

	return unless @$expression_list;

	my @bytecode;
	if (@$expression_list > 1) {
		foreach my $i (0 .. $#$expression_list - 1) {
			push @bytecode, $self->parse_bytecode_expression(single => $expression_list->[$i]);
		}
	}
	push @bytecode, $self->parse_bytecode_expression(multi => $expression_list->[-1]);

	return @bytecode
}


sub parse_bytecode_expression {
	my ($self, $stack_mode, $expression) = @_;

	if ($expression->{type} eq 'nil_constant') {
		return ps => $lua_nil_constant
	} elsif ($expression->{type} eq 'bool_constant') {
		return ps => [ boolean => $expression->{value} ]
	} elsif ($expression->{type} eq 'numeric_constant') {
		return ps => [ number => $expression->{value} ]
	} elsif ($expression->{type} eq 'string_constant') {
		return ps => [ string => $expression->{value} ]
	} elsif ($expression->{type} eq 'parenthesis_expression') {
		return $self->parse_bytecode_expression(single => $expression->{expression})
	} elsif ($expression->{type} eq 'vararg_expression') {
		die "vararg expression used in non-vararg function" unless $self->{is_vararg_chunk};
		return dv => undef if $stack_mode eq 'single';
		return lv => undef
	} elsif ($expression->{type} eq 'identifier_expression') {
		return $self->parse_bytecode_identifier($expression->{identifier})
	} elsif ($expression->{type} eq 'access_expression') {
		return $self->parse_bytecode_expression(single => $expression->{expression}),
			lo => $expression->{identifier}
	} elsif ($expression->{type} eq 'expressive_access_expression') {
		return
			$self->parse_bytecode_expression(single => $expression->{expression}),
			$self->parse_bytecode_expression(single => $expression->{access_expression}),
			mo => $expression->{identifier},
	} elsif ($expression->{type} eq 'unary_expression') {
		return
			$self->parse_bytecode_expression(single => $expression->{expression}),
			un => $expression->{operation},
	} elsif ($expression->{type} eq 'binary_expression') {
		return
			$self->parse_bytecode_expression(single => $expression->{expression_left}),
			$self->parse_bytecode_expression(single => $expression->{expression_right}),
			bn => $expression->{operation},
	} elsif ($expression->{type} eq 'table_expression') {
		my @code = (
			co => undef,
		);
		foreach my $field (@{$expression->{table_fields}}) {
			if ($field->{type} eq 'expressive_field') {
				push @code,
					$self->parse_bytecode_expression(single => $field->{key_expression}),
					$self->parse_bytecode_expression(single => $field->{expression}),
					eo => undef,
				;
			} elsif ($field->{type} eq 'identifier_field') {
				push @code,
					$self->parse_bytecode_expression(single => $field->{expression}),
					io => $field->{identifier},
				;
			} elsif ($field->{type} eq 'array_field') {
				push @code,
					$self->parse_bytecode_expression(single => $field->{expression}),
					ao => undef,
				;
			} else {
				die "unimplemented field type $field->{type}";
			}
		}
		return @code;
	} elsif ($expression->{type} eq 'function_expression') {
		my $function_val = {
			chunk => $expression->{block},
			args_list => $expression->{args_list},
			closure_list => [],
			closure_map => {},
			variable_context => $self->compile_variable_context,
			parent_chunk => $self->{current_chunk},
			sourcefile => $self->{current_chunk}{sourcefile},
		};
		push @{$self->{bytecode_chunk_queue}}, $function_val;
		return
			pf => [ function => $function_val ],

	} elsif ($expression->{type} eq 'function_call_expression') {
		return
			ss => undef,
			$self->parse_bytecode_expression(single => $expression->{expression}),
			$self->parse_bytecode_expression_list($expression->{args_list}),
			cf => undef,
			( ts => 1 ) x ($stack_mode eq 'single'),
			ms => undef,
	} elsif ($expression->{type} eq 'method_call_expression') {
		return
			ss => undef,
			$self->parse_bytecode_expression(single => $expression->{expression}),
			bs => undef,
			lo => $expression->{identifier},
			rs => undef,
			$self->parse_bytecode_expression_list($expression->{args_list}),
			cf => undef,
			( ts => 1 ) x ($stack_mode eq 'single'),
			ms => undef,
	} else {
		die "unimplemented expression type $expression->{type}";
	}
}

sub parse_bytecode_lvalue_expression {
	my ($self, $expression) = @_;

	if ($expression->{type} eq 'identifier_expression') {
		return $self->parse_bytecode_lvalue_identifier($expression->{identifier})
	} elsif ($expression->{type} eq 'access_expression') {
		return
			$self->parse_bytecode_expression(single => $expression->{expression}),
			so => $expression->{identifier},
	} elsif ($expression->{type} eq 'expressive_access_expression') {
		return
			$self->parse_bytecode_expression(single => $expression->{expression}),
			$self->parse_bytecode_expression(single => $expression->{access_expression}),
			vo => $expression->{identifier},
	} else {
		die "unimplemented expression type $expression->{type}";
	}
}


sub parse_bytecode_identifier {
	my ($self, $identifier) = @_;

	return ll => $self->{current_local_scope}{$identifier} if defined $self->{current_local_scope} and exists $self->{current_local_scope}{$identifier};

	foreach my $i (reverse 0 .. $#{$self->{local_scope_stack}}) {
		return ll => $self->{local_scope_stack}[$i]{$identifier} if exists $self->{local_scope_stack}[$i]{$identifier};
	}

	my @chunk_stack;
	my $chunk = $self->{current_chunk};
	while (defined $chunk) {
		push @chunk_stack, $chunk;
		if (defined $chunk->{variable_context} and exists $chunk->{variable_context}{$identifier}) {
			my $index = "$chunk->{variable_context}{$identifier}";
			while ($chunk = pop @chunk_stack) {
				unless (exists $chunk->{closure_map}{$index}) {
					push @{$chunk->{closure_list}}, $index;
					$chunk->{closure_map}{$index} = "c$#{$chunk->{closure_list}}"
				}
				$index = $chunk->{closure_map}{$index};
			}
			$index = int ($index =~ s/^c(\d+)$/$1/r);
			return lc => $index
		}
		$chunk = $chunk->{parent_chunk};
	}

	return lg => $identifier
}


sub parse_bytecode_lvalue_identifier {
	my ($self, $identifier) = @_;

	my ($op, $arg) = $self->parse_bytecode_identifier($identifier);
	return $op =~ s/^l/s/r, $arg
}

sub parse_bytecode_user_label {
	my ($self, $label) = @_;

	return $self->{current_local_labels}{$label} if defined $self->{current_local_labels} and exists $self->{current_local_labels}{$label};

	foreach my $i (reverse 0 .. $#{$self->{local_label_stack}}) {
		return $self->{local_label_stack}[$i]{$label} if exists $self->{local_label_stack}[$i]{$label};
	}

	die "missing user label $label";
}

sub dump_bytecode {
	my ($self, $bytecode) = @_;
	$bytecode = $bytecode // $self->{bytecode_chunk};

	my $s = '';
	my $i = 0;
	while ($i < @$bytecode) {
		my $op = $bytecode->[$i++];
		my $arg = $bytecode->[$i++];
		$s .= "\t$op" . (ref $arg ? " => $arg->[0] [$arg->[1]]" : defined $arg ? " => $arg" : '') . "\n";
	}
	return $s
}


sub compile_variable_context {
	my ($self) = @_;
	my %context = ( (map { {%$_} } @{$self->{local_scope_stack}}), %{$self->{current_local_scope}} );
	return \%context
}



1

