package Snow::Lua::Bytecode;
use parent 'Snow::Lua::SyntaxParser';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;
use Carp;



our $lua_nil_constant = [ nil => 'nil' ];



sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);
	return $self;
}



sub parse {
	my ($self, $text) = @_;
	$self->SUPER::parse($text);

	$self->{bytecode_chunk} = $self->parse_bytecode_chunk($self->{syntax_tree});
	say $self->dump_bytecode;
	return $self->{bytecode_chunk}
}

sub parse_bytecode_chunk {
	my ($self, $chunk) = @_;

	$self->{local_scope_stack} = [];
	$self->{current_local_index} = 0;
	$self->{current_local_scope} = undef;

	my $block = [ $self->parse_bytecode_block($chunk) ];

	return $block
}

sub parse_bytecode_block {
	my ($self, $block) = @_;

	push @{$self->{local_scope_stack}}, $self->{current_local_scope} if defined $self->{current_local_scope};
	$self->{current_local_scope} = {};

	my $locals_loaded = 0;
	# need to precompute how many locals are loaded in order to properly support goto

	my @bytecode;
	foreach my $statement (@$block) {
		if ($statement->{type} eq 'empty_statement') {
			# nothing
		} elsif ($statement->{type} eq 'block_statement') {
			push @bytecode, $self->parse_bytecode_block($statement->{block});
		} elsif ($statement->{type} eq 'variable_declaration_statement') {
			foreach my $name (@{$statement->{names_list}}) {
				$self->{current_local_scope}{$name} = $self->{current_local_index}++;
				$locals_loaded++;
			}
			push @bytecode, xl => scalar @{$statement->{names_list}};
			if (defined $statement->{expression_list}) {
				push @bytecode, ss => undef;
				push @bytecode, $self->parse_bytecode_expression_list($statement->{expression_list});
				# push @bytecode, ts => scalar @{$statement->{names_list}};
				push @bytecode, rs => undef;
				foreach my $name (@{$statement->{names_list}}) {
					push @bytecode, sl => $self->{current_local_scope}{$name};
				}
				push @bytecode, ds => undef;
			}
		} elsif ($statement->{type} eq 'assignment_statement') {
			push @bytecode, ss => undef;
			push @bytecode, $self->parse_bytecode_expression_list($statement->{expression_list});
			push @bytecode, rs => undef;
			foreach my $var (@{$statement->{var_list}}) {
				push @bytecode, $self->parse_bytecode_lvalue_expression($var);
			}
			push @bytecode, ds => undef;

		} elsif ($statement->{type} eq 'call_statement') {
			push @bytecode, ss => undef;
			push @bytecode, $self->parse_bytecode_expression($statement->{expression});
			push @bytecode, ds => undef;
		} elsif ($statement->{type} eq 'until_statement') {
			# TODO support local variable application in the expression part (WHY lua???)
			my @expression = $self->parse_bytecode_expression($statement->{expression});
			my @block = $self->parse_bytecode_block($statement->{block});
			push @bytecode, @block;
			push @bytecode, @expression;
			push @bytecode, bt => undef;
			push @bytecode, fj => -4 - scalar (@expression) - scalar @block;
		} elsif ($statement->{type} eq 'while_statement') {
			my @expression = $self->parse_bytecode_expression($statement->{expression});
			my @block = $self->parse_bytecode_block($statement->{block});
			push @bytecode, @expression;
			push @bytecode, bt => undef;
			push @bytecode, fj => 2 + scalar @block;
			push @bytecode, @block;
			push @bytecode, aj => - scalar (@expression) -6 - scalar @block;
		} elsif ($statement->{type} eq 'if_statement') {
			my @block = $self->parse_bytecode_block($statement->{block});
			push @bytecode, $self->parse_bytecode_expression($statement->{expression});
			push @bytecode, bt => undef;

			if (defined $statement->{branch}) {
				my $brach_statement = $statement->{branch};
				my @branch_block = $self->parse_bytecode_block($brach_statement->{block});
				push @bytecode, fj => 2 + scalar @block;
				push @bytecode, @block;
				push @bytecode, aj => scalar @branch_block;
				push @bytecode, @branch_block;
			} else {
				push @bytecode, fj => scalar @block;
				push @bytecode, @block;
			}

		} elsif ($statement->{type} eq 'return_statement') {
			push @bytecode, $self->parse_bytecode_expression_list($statement->{expression_list});
			push @bytecode, rt => undef;
		} else {
			die "unimplemented statement type $statement->{type}";
		}
	}

	if ($locals_loaded > 0) {
		push @bytecode, tl => $locals_loaded;
		$self->{current_local_index} -= $locals_loaded;
	}

	# say Dumper $self->{current_local_scope};
	$self->{current_local_scope} = shift @{$self->{local_scope_stack}} if @{$self->{local_scope_stack}};

	return @bytecode
}



sub parse_bytecode_expression_list {
	my ($self, $expression_list) = @_;

	return unless @$expression_list;

	my @bytecode;
	if (@$expression_list > 1) {
		push @bytecode, ss => undef;
		foreach my $i (0 .. $#$expression_list - 1) {
			push @bytecode, $self->parse_bytecode_expression($expression_list->[$i]);
			push @bytecode, ts => $i + 1;
		}
		push @bytecode, ls => @$expression_list - 1;
	}
	push @bytecode, $self->parse_bytecode_expression($expression_list->[-1]);

	return @bytecode
}


sub parse_bytecode_expression {
	my ($self, $expression) = @_;

	if ($expression->{type} eq 'nil_constant') {
		return ps => $lua_nil_constant
	} elsif ($expression->{type} eq 'bool_constant') {
		return ps => [ bool => $expression->{value} ]
	} elsif ($expression->{type} eq 'numeric_constant') {
		return ps => [ number => $expression->{value} ]
	} elsif ($expression->{type} eq 'string_constant') {
		return ps => [ string => $expression->{value} ]
	} elsif ($expression->{type} eq 'parenthesis_expression') {
		return $self->parse_bytecode_expression($expression->{expression})
	} elsif ($expression->{type} eq 'identifier_expression') {
		return $self->parse_bytecode_identifier($expression->{identifier})
	} elsif ($expression->{type} eq 'unary_expression') {
		return
			ss => undef,
			$self->parse_bytecode_expression($expression->{expression}),
			ts => 1,
			un => $expression->{operation},
			ls => 1,
	} elsif ($expression->{type} eq 'binary_expression') {
		return
			ss => undef,
			$self->parse_bytecode_expression($expression->{expression_left}),
			ts => 1,
			$self->parse_bytecode_expression($expression->{expression_right}),
			ts => 2,
			bn => $expression->{operation},
			ls => 1,
	} elsif ($expression->{type} eq 'function_call_expression') {
		return
			$self->parse_bytecode_expression($expression->{expression}),
			ss => undef,
			$self->parse_bytecode_expression_list($expression->{args_list}),
			fc => undef
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
			$self->parse_bytecode_expression($expression->{expression}),
			so => $expression->{identifier}
	} elsif ($expression->{type} eq 'expressive_access_expression') {
		... #TODO
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

	# TODO implement closure load

	return lg => $identifier
}


sub parse_bytecode_lvalue_identifier {
	my ($self, $identifier) = @_;

	return sl => $self->{current_local_scope}{$identifier} if defined $self->{current_local_scope} and exists $self->{current_local_scope}{$identifier};

	foreach my $i (reverse 0 .. $#{$self->{local_scope_stack}}) {
		return sl => $self->{local_scope_stack}[$i]{$identifier} if exists $self->{local_scope_stack}[$i]{$identifier};
	}

	# TODO implement closure load

	return sg => $identifier
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



1

