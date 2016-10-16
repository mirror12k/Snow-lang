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
}



sub parse_syntax_block {
	my ($self) = @_;

	my @block;
	while (my $statement = $self->parse_syntax_statement) {
		push @block, $statement;
	}
	my $statement = $self->parse_syntax_return_statement;
	push @block, $statement if defined $statement;

	$self->confess_at_current_offset('more tokens found after end of code') if $self->more_tokens;

	return \@block
}



sub parse_syntax_statement {
	my ($self) = @_;

	return undef unless $self->more_tokens;
	
	if ($self->is_token_val( symbol => '::' )) {
		$self->next_token;
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		$self->assert_step_token_val(symbol => '::');
		return { type => 'label_statement', identifier => $identifier }

	} elsif ($self->is_token_val( keyword => 'break' )) {
		$self->next_token;
		return { type => 'break_statement' }

	} elsif ($self->is_token_val( keyword => 'goto' )) {
		$self->next_token;
		my $identifier = $self->assert_step_token_type('identifier')->[1];
		return { type => 'goto_statement', identifier => $identifier }

	} elsif ($self->is_token_val( symbol => ';' )) {
		$self->next_token;
		return { type => 'empty_statement' }

	}

	return undef
}

sub parse_syntax_return_statement {
	my ($self) = @_;
	

	return undef
}


sub dump {
	my ($self) = @_;
	...
}



1;

