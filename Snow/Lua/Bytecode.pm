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
	return $self->{bytecode_chunk}
}

sub parse_bytecode_chunk {
	my ($self, $chunk) = @_;

	$self->{local_scope_stack} = [];
	$self->{current_local_index} = 0;
	$self->{current_local_scope} = undef;

	$self->{local_label_stack} = [];
	$self->{current_local_labels} = undef;

	$self->{current_break_label} = undef;

	$self->{current_jump_index} = 0;



	my @block = $self->parse_bytecode_block($chunk);
	say "dump bytecode labels:\n", $self->dump_bytecode(\@block); # inspect final bytecode
	my @bytecode = $self->resolve_bytecode_labels(@block);
	unshift @bytecode, xl => $self->{current_local_index} if $self->{current_local_index} > 0;
	say "dump bytecode:\n", $self->dump_bytecode(\@bytecode); # inspect final bytecode

	return [ @bytecode ]
}

sub parse_bytecode_block {
	my ($self, $block) = @_;

	push @{$self->{local_scope_stack}}, $self->{current_local_scope} if defined $self->{current_local_scope};
	$self->{current_local_scope} = {};
	push @{$self->{local_label_stack}}, $self->{current_local_labels} if defined $self->{current_local_labels};
	$self->{current_local_labels} = {};

	my $locals_loaded = 0;
	# need to precompute how many locals are loaded in order to properly support goto

	# run through once to collect all local labels
	foreach my $statement (@$block) {
		if ($statement->{type} eq 'label_statement') {
			$self->{current_local_labels}{$statement->{identifier}} = "user_label_" . $self->{current_jump_index}++;
		}
	}

	my @bytecode;
	foreach my $statement (@$block) {
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
			# $locals_loaded += @{$statement->{names_list}};
			# push @bytecode, xl => scalar @{$statement->{names_list}};
			if (defined $statement->{expression_list}) {
				push @bytecode,
					ss => undef,
					$self->parse_bytecode_expression_list($statement->{expression_list}),
					rs => undef,
					( map +( sl => $self->{current_local_scope}{$_} ), @{$statement->{names_list}} ),
					ds => undef,
			}
		} elsif ($statement->{type} eq 'assignment_statement') {
			push @bytecode,
				ss => undef,
				$self->parse_bytecode_expression_list($statement->{expression_list}),
				rs => undef,
				( map $self->parse_bytecode_lvalue_expression($_), @{$statement->{var_list}} ),
				ds => undef,
		} elsif ($statement->{type} eq 'call_statement') {
			push @bytecode,
				ss => undef,
				$self->parse_bytecode_expression($statement->{expression}),
				ds => undef,
		} elsif ($statement->{type} eq 'until_statement') {
			# TODO support local variable application in the expression part (WHY lua???)
			my $repeat_label = "repeat_" . $self->{current_jump_index}++;
			my $end_label = "repeat_end_" . $self->{current_jump_index}++;
			my $last_break_label = $self->{current_break_label};
			$self->{current_break_label} = $end_label;
			push @bytecode,
				_label => $repeat_label,
				$self->parse_bytecode_block($statement->{block}),
				$self->parse_bytecode_expression($statement->{expression}),
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
				$self->parse_bytecode_expression($statement->{expression}),
				bt => undef,
				fj => $end_label,
				$self->parse_bytecode_block($statement->{block}),
				aj => $expression_label,
				_label => $end_label,
			;
			$self->{current_break_label} = $last_break_label;
		} elsif ($statement->{type} eq 'if_statement') {
			my $branch_label = "branch_" . $self->{current_jump_index}++;
			push @bytecode,
				$self->parse_bytecode_expression($statement->{expression}),
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
						$self->parse_bytecode_expression($branch_statement->{expression}),
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
				rt => undef,
		} else {
			die "unimplemented statement type $statement->{type}";
		}
	}

	# if ($locals_loaded > 0) {
	# 	push @bytecode, tl => $locals_loaded;
	# 	# $self->{current_local_index} -= $locals_loaded;
	# }

	# say Dumper $self->{current_local_scope};
	$self->{current_local_scope} = shift @{$self->{local_scope_stack}} if @{$self->{local_scope_stack}};
	$self->{current_local_labels} = shift @{$self->{local_label_stack}} if @{$self->{local_label_stack}};

	return @bytecode
}

# sub resolve_locals_size {
# 	my ($self, @block) = @_;
# 	foreach my $index (0 .. (@block / 2 - 1)) {
# 		my $op = $block[$index * 2];
# 		my $arg = $block[$index * 2 + 1];
# 	}
# }


sub resolve_bytecode_labels {
	my ($self, @block) = @_;

	my @bytecode;
	my %labels;

	while (@block) {
		my $op = shift @block;
		my $arg = shift @block;

		if ($op eq '_label') {
			$labels{$arg} = scalar @bytecode;
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



1

