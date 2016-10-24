package Snow::Lua::SyntaxStringer;
use strict;
use warnings;

use feature 'say';

use Carp;




sub new {
	my ($class, %opts) = @_;
	my $self = bless {}, $class;
	return $self
}



sub to_string {
	my ($self, $syntax_tree) = @_;

	$self->{syntax_tree} = $syntax_tree;
	$self->{text} =  $self->to_string_block($self->{syntax_tree}, '') . "\n";

	return $self->{text}
}

sub to_string_block {
	my ($self, $block, $prefix) = @_;

	my $text = '';
	foreach my $statement (@$block) {
		$text .= $self->to_string_statement($statement, $prefix) . "\n";
	}

	return $text;
}

sub to_string_statement {
	my ($self, $statement, $prefix) = @_;

	if ($statement->{type} eq 'empty_statement') {
		return "${prefix};"
	} elsif ($statement->{type} eq 'break_statement') {
		return "${prefix}break"
	} elsif ($statement->{type} eq 'label_statement') {
		return "${prefix}::$statement->{identifier}::"
	} elsif ($statement->{type} eq 'goto_statement') {
		return "${prefix}goto $statement->{identifier}"
	} elsif ($statement->{type} eq 'block_statement') {
		return "${prefix}do\n" . $self->to_string_block($statement->{block}, "${prefix}\t") . "${prefix}end"
	} elsif ($statement->{type} eq 'while_statement') {
		return "${prefix}while " . $self->to_string_expression($statement->{expression}) . " do\n"
			. $self->to_string_block($statement->{block}, "${prefix}\t") . "${prefix}end"
	} elsif ($statement->{type} eq 'until_statement') {
		return "${prefix}repeat\n" . $self->to_string_block($statement->{block}, "${prefix}\t")
			. "${prefix}until " . $self->to_string_expression($statement->{expression})
	} elsif ($statement->{type} eq 'if_statement') {
		return "${prefix}if " . $self->to_string_expression($statement->{expression}) . " then\n"
			. $self->to_string_block($statement->{block}, "${prefix}\t")
			. (defined $statement->{branch} ? $self->to_string_statement($statement->{branch}, $prefix) : "${prefix}end")
	} elsif ($statement->{type} eq 'elseif_statement') {
		return "${prefix}elseif " . $self->to_string_expression($statement->{expression}) . " then\n"
			. $self->to_string_block($statement->{block}, "${prefix}\t")
			. (defined $statement->{branch} ? $self->to_string_statement($statement->{branch}, $prefix) : "${prefix}end")
	} elsif ($statement->{type} eq 'else_statement') {
		return "${prefix}else\n" . $self->to_string_block($statement->{block}, "${prefix}\t")
			. "${prefix}end"
	} elsif ($statement->{type} eq 'for_statement') {
		return "${prefix}for $statement->{identifier} = " . $self->to_string_expression($statement->{expression_start}) . ", "
			. $self->to_string_expression($statement->{expression_end})
			. ( defined $statement->{expression_step} ? ", " . $self->to_string_expression($statement->{expression_step}) : '')
			. " do\n"
			. $self->to_string_block($statement->{block}, "${prefix}\t") . "${prefix}end"
	} elsif ($statement->{type} eq 'iter_statement') {
		return "${prefix}for " . join (", ", @{$statement->{names_list}}) . " in "
			. $self->to_string_expression_list($statement->{expression_list}) . " do\n"
			. $self->to_string_block($statement->{block}, "${prefix}\t") . "${prefix}end"

	} elsif ($statement->{type} eq 'variable_declaration_statement') {
		return "${prefix}local " . join (", ", @{$statement->{names_list}})
			. ( defined $statement->{expression_list} ? ' = ' . $self->to_string_expression_list($statement->{expression_list}) : '' )
	} elsif ($statement->{type} eq 'call_statement') {
		return "${prefix}" . $self->to_string_expression($statement->{expression}) . ";"
	} else {
		die "unimplemented statement type $statement->{type}";
	}
}

sub to_string_expression_list {
	my ($self, $expression_list) = @_;
	return join ", ", map $self->to_string_expression($_), @$expression_list
}

sub to_string_expression {
	my ($self, $expression) = @_;
	if ($expression->{type} eq 'nil_constant') {
		return "nil"
	} elsif ($expression->{type} eq 'bool_constant') {
		return $expression->{value} ? "true" : "false"
	} elsif ($expression->{type} eq 'numeric_constant') {
		return "$expression->{value}"
	} elsif ($expression->{type} eq 'string_constant') {
		return "'$expression->{value}'"
	} elsif ($expression->{type} eq 'identifier_expression') {
		return "$expression->{identifier}"
	} elsif ($expression->{type} eq 'access_expression') {
		return $self->to_string_expression($expression->{expression}) . ".$expression->{identifier}"
	} elsif ($expression->{type} eq 'function_call_expression') {
		return $self->to_string_expression($expression->{expression}) . "(" . $self->to_string_expression_list($expression->{args_list}) . ")"
	} else {
		die "unimplemented expression type $expression->{type}";
	}
}



1;
