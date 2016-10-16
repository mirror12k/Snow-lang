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
	while (my $statement = $self->parse_syntax_statement) {
		push @block, $statement;
	}
	my $statement = $self->parse_syntax_return_statement;
	push @block, $statement if defined $statement;


	return \@block
}



sub parse_syntax_statement {
	my ($self) = @_;

	return undef unless $self->more_tokens;

	my $statement;
	if ($self->is_token_val( symbol => '::' )) {
		$self->next_token;
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		$self->assert_step_token_val(symbol => '::');
		$statement = { type => 'label_statement', identifier => $identifier };

	} elsif ($self->is_token_val( keyword => 'break' )) {
		$self->next_token;
		$statement = { type => 'break_statement' };

	} elsif ($self->is_token_val( keyword => 'goto' )) {
		$self->next_token;
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		$statement = { type => 'goto_statement', identifier => $identifier };

	} elsif ($self->is_token_val( keyword => 'do' )) {
		$self->next_token;
		$statement = { type => 'block_statement', block => $self->parse_syntax_block };
		$self->assert_step_token_val(keyword => 'end');

	} elsif ($self->is_token_val( keyword => 'while' )) {
		$self->next_token;
		my $expression = $self->parse_syntax_expression;
		$self->assert_step_token_val(keyword => 'do');
		$statement = { type => 'while_statement', expression => $expression, block => $self->parse_syntax_block };
		$self->assert_step_token_val(keyword => 'end');

	} elsif ($self->is_token_val( keyword => 'if' )) {
		$self->next_token;
		my $expression = $self->parse_syntax_expression;
		$self->assert_step_token_val(keyword => 'then');
		$statement = { type => 'if_statement', expression => $expression, block => $self->parse_syntax_block };

		my $branching_statement = $statement;
		while ($self->is_token_val( keyword => 'elseif' )) {
			warn "got elseif";
			$self->next_token;
			$expression = $self->parse_syntax_expression;
			$self->assert_step_token_val(keyword => 'then');
			$branching_statement->{branch} = { type => 'elseif_statement', expression => $expression, block => $self->parse_syntax_block };
			$branching_statement = $branching_statement->{branch};
		}
		if ($self->is_token_val( keyword => 'else' )) {
			warn "got else";
			$self->next_token;
			$branching_statement->{branch} = { type => 'else_statement', block => $self->parse_syntax_block };
		}

		$self->assert_step_token_val(keyword => 'end');

	} elsif ($self->is_token_val( symbol => ';' )) {
		$self->next_token;
		$statement = { type => 'empty_statement' };

	}

	return $statement
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
		my $value = 0 + $self->next_token->[1];
		$expression = { type => 'numeric_constant', value => $value };
		
	} elsif ($self->is_token_type('literal_string')) {
		my $value = $self->next_token->[1];
		$expression = { type => 'literal_string', value => $value };

	} elsif ($self->is_token_val( symbol => '...' )) {
		$self->next_token;
		$expression = { type => 'vararg_expression' };

	} else {
		$self->confess_at_current_offset('expression expected');
	}

	return $expression
}


# sub dump {
# 	my ($self) = @_;
# 	...
# }



1;

