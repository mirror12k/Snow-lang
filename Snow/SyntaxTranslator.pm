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

	return $self
}




sub parse {
	my ($self, $text) = @_;
	$self->SUPER::parse($text);

	$self->{variables_stack} = [];
	$self->{variables_defined} = {
		print => '&',
	};
	$self->{globals_defined} = {
		print => '&',
	};

	$self->{syntax_tree} = [ $self->translate_syntax_block($self->{syntax_tree}) ];

	return $self->{syntax_tree}
}


sub new_snow_label {
	my ($self, $prefix) = @_;
	return "_snow_${prefix}__" . $self->{snow_label_index}++
}

sub push_snow_loop_labels {
	my ($self) = @_;
	push @{$self->{snow_last_label_stack}}, $self->{snow_last_label};
	$self->{snow_last_label} = $self->new_snow_label('last');
	push @{$self->{snow_next_label_stack}}, $self->{snow_next_label};
	$self->{snow_next_label} = $self->new_snow_label('next');
	push @{$self->{snow_redo_label_stack}}, $self->{snow_redo_label};
	$self->{snow_redo_label} = $self->new_snow_label('redo');
}

sub pop_snow_loop_labels {
	my ($self) = @_;
	$self->{snow_last_label} = pop @{$self->{snow_last_label_stack}};
	$self->{snow_next_label} = pop @{$self->{snow_next_label_stack}};
	$self->{snow_redo_label} = pop @{$self->{snow_redo_label_stack}};
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
	my ($self, $block) = @_;

	push @{$self->{variables_stack}}, $self->{variables_defined};
	$self->{variables_defined} = {};
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
		return { type => 'goto_statement', identifier => $self->{snow_last_label} }

	} elsif ($statement->{type} eq 'next_statement') {
		die "next used outside of a loop" unless defined $self->{snow_next_label};
		return { type => 'goto_statement', identifier => $self->{snow_next_label} }

	} elsif ($statement->{type} eq 'redo_statement') {
		die "redo used outside of a loop" unless defined $self->{snow_redo_label};
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
		my @statements = ({
			type => 'while_statement',
			expression => $self->translate_syntax_expression($statement->{expression}),
			block => [
				{ type => 'label_statement', identifier => $self->{snow_redo_label} },
				$self->translate_syntax_block($statement->{block}),
				{ type => 'label_statement', identifier => $self->{snow_next_label} },
			],
		});
		if (defined $statement->{branch}) {
			push @statements, { type => 'block_statement', block => [ $self->translate_syntax_block($statement->{branch}{block}) ] }
		}
		push @statements, { type => 'label_statement', identifier => $self->{snow_last_label} };
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
	} elsif ($statement->{type} eq 'global_declaration_statement') {
		# TODO: verify assignment types
		$self->register_globals(@{$statement->{names_list}});
		return

	} elsif ($statement->{type} eq 'call_statement') {
		return {
			type => 'call_statement',
			expression => $self->translate_syntax_expression($statement->{expression}),
		}
	} elsif ($statement->{type} eq 'assignment_statement') {
		# TODO: verify assignment types
		return {
			type => 'assignment_statement',
			var_list => [ $self->translate_syntax_expression_list($statement->{var_list}) ],
			expression_list => [ $self->translate_syntax_expression_list($statement->{expression_list}) ],
		};

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
		return $expression

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
		if ($expression->{operation} eq '+') {
			# TODO implement dynamic translation to concatenation
			$var_type = '#';
		} elsif ($expression->{operation} eq '-' or $expression->{operation} eq '*' or $expression->{operation} eq '/') {
			$var_type = '#';
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
		return { type => 'identifier_expression', identifier => $expression->{identifier}, expression => $sub_expression, var_type => '*' }

	} elsif ($expression->{type} eq 'expressive_access_expression') {
		my $sub_expression = $self->translate_syntax_expression($expression->{expression});
		my $access_expression = $self->translate_syntax_expression($expression->{access_expression});
		return { type => 'identifier_expression', identifier => $expression->{identifier}, expression => $sub_expression,
				access_expression => $access_expression, var_type => '*' }
		
	} elsif ($expression->{type} eq 'function_call_expression') {
		my $sub_expression = $self->translate_syntax_expression($expression->{expression});
		$self->assert_sub_expression_type('&' => $sub_expression);
		return {
			type => 'function_call_expression',
			expression => $sub_expression,
			args_list => [ $self->translate_syntax_expression_list($expression->{args_list}) ],
		}
		
	} elsif ($expression->{type} eq 'method_call_expression') {
		my $sub_expression = $self->translate_syntax_expression($expression->{expression});
		$self->assert_sub_expression_type('%' => $sub_expression);
		return {
			type => 'method_call_expression',
			identifier => $expression->{identifier},
			expression => $sub_expression,
			args_list => [ $self->translate_syntax_expression_list($expression->{args_list}) ],
		}

	} else {
		die "unimplemented expression in translation $expression->{type}";
	}
}

sub translate_syntax_expression_list {
	my ($self, $expression_list) = @_;

	return map $self->translate_syntax_expression($_), @$expression_list
}




1;
