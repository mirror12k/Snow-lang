package Snow::Lua::Bytecode;
use parent 'Snow::Lua::SyntaxParser';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;
use Carp;



our $lua_nil_constant = [ nil => '' ];



sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);
	return $self;
}



sub parse {
	my ($self, $text) = @_;
	$self->SUPER::parse($text);

	$self->{bytecode_chunk} = [ $self->parse_bytecode_block($self->{syntax_tree}) ];
	return $self->{bytecode_chunk}
}

sub parse_bytecode_block {
	my ($self, $block) = @_;

	my @bytecode;
	foreach my $statement (@$block) {
		# if ($statement->{type} eq 'return_statement') {
		# 	return rt => [ $self->interpret_expression_list($statement->{expression_list}) ];
		# } els
		if ($statement->{type} eq 'call_statement') {
			push @bytecode, ss => undef;
			push @bytecode, $self->parse_bytecode_expression($statement->{expression});
			push @bytecode, ls => -1;
		} else {
			die "unimplemented statement type $statement->{type}";
		}
	}

	return @bytecode
}



sub parse_bytecode_expression_list {
	my ($self, $expression_list) = @_;

	return unless @$expression_list;

	my @bytecode;
	foreach my $i (0 .. $#$expression_list - 1) {
		push @bytecode, ss => undef;
		push @bytecode, $self->parse_bytecode_expression($expression_list->[$i]);
		push @bytecode, ls => 0;
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


sub parse_bytecode_identifier {
	my ($self, $identifier) = @_;
	return gl => $identifier
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

