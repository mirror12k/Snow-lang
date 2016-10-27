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
	return $self;
}




sub parse {
	my ($self, $text) = @_;
	$self->SUPER::parse($text);

	$self->{syntax_tree} = $self->translate_syntax_block($self->{syntax_tree});

	return $self->{syntax_tree}
}


sub translate_syntax_block {
	my ($self, $block) = @_;

	return [ map $self->translate_syntax_statement($_), @$block ]
}



sub translate_syntax_statement {
	my ($self, $statement) = @_;

	if ($statement->{type} eq 'label_statement') {
		return $statement

	} elsif ($statement->{type} eq 'goto_statement') {
		return $statement

	} elsif ($statement->{type} eq 'break_statement') {
		return $statement

	} elsif ($statement->{type} eq 'block_statement') {
		return { type => 'block_statement', block => $self->translate_syntax_block($statement->{block}) }

	} elsif ($statement->{type} eq 'while_statement') {
		return {
			type => 'while_statement',
			expression => $self->translate_syntax_expression($statement->{expression}),
			block => $self->translate_syntax_block($statement->{block}),
		}

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

	} elsif ($expression->{type} eq 'identifier_expression') {
		return $expression
		
	} elsif ($expression->{type} eq 'function_call_expression') {
		return {
			type => 'function_call_expression',
			expression => $self->translate_syntax_expression($expression->{expression}),
			args_list => $self->translate_syntax_expression_list($expression->{args_list}),
		}

	} else {
		die "unimplemented expression in translation $expression->{type}";
	}
}

sub translate_syntax_expression_list {
	my ($self, $expression_list) = @_;

	return [ map $self->translate_syntax_expression($_), @$expression_list ]
}




1;

