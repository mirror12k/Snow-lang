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

sub translate_syntax_block {
	my ($self, $block) = @_;

	return map $self->translate_syntax_statement($_), @$block
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
			(branch => (defined $statement->{branch} ? $self->translate_syntax_statement($statement->{branch}) : undef)),
		}
		
	} elsif ($statement->{type} eq 'elseif_statement') {
		return {
			type => 'elseif_statement',
			expression => $self->translate_syntax_expression($statement->{expression}),
			block => [ $self->translate_syntax_block($statement->{block}) ],
			(branch => (defined $statement->{branch} ? $self->translate_syntax_statement($statement->{branch}) : undef)),
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

	} elsif ($statement->{type} eq 'call_statement') {
		return {
			type => 'call_statement',
			expression => $self->translate_syntax_expression($statement->{expression}),
		}

	} else {
		die "unimplemented statement to translate: $statement->{type}";
	}

}


sub translate_syntax_expression {
	my ($self, $expression) = @_;


	if ($expression->{type} eq 'nil_constant') {
		return $expression

	} elsif ($expression->{type} eq 'boolean_constant') {
		return $expression
		
	} elsif ($expression->{type} eq 'numeric_constant') {
		return $expression
		
	} elsif ($expression->{type} eq 'string_constant') {
		# TODO: parse interpolation stuff
		return $expression

	} elsif ($expression->{type} eq 'vararg_expression') {
		return $expression

	} elsif ($expression->{type} eq 'parenthesis_expression') {
		return { type => 'parenthesis_expression', expression => $self->translate_syntax_expression($expression->{expression}) }

	} elsif ($expression->{type} eq 'unary_expression') {
		return { type => 'unary_expression', operation => $expression->{operation}, expression => $self->translate_syntax_expression($expression->{expression}) }

	} elsif ($expression->{type} eq 'identifier_expression') {
		return $expression
		
	} elsif ($expression->{type} eq 'function_call_expression') {
		return {
			type => 'function_call_expression',
			expression => $self->translate_syntax_expression($expression->{expression}),
			args_list => [ $self->translate_syntax_expression_list($expression->{args_list}) ],
		}
		
	} elsif ($expression->{type} eq 'method_call_expression') {
		return {
			type => 'method_call_expression',
			identifier => $expression->{identifier},
			expression => $self->translate_syntax_expression($expression->{expression}),
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

