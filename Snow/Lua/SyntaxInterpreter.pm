package Snow::Lua::SyntaxInterpreter;
use parent 'Snow::Lua::SyntaxParser';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;
use Carp;




sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);
	return $self;
}


sub interpret {
	my ($self) = @_;
	my $ret = $self->interpret_block($self->{syntax_tree});
	say "main returned: ", Dumper $ret;
}

sub interpret_block {
	my ($self, $block) = @_;

	my $i = 0;
	while ($i < @$block) {
		my $statement = $block->[$i];
		if ($statement->{type} eq 'return_statement') {
			return return => [ $self->interpret_expression_list($statement->{expression_list}) ]
		} else {
			die "unimplemented statement type $statement->{type}";
		}
		$i++;
	}
	return
}

sub interpret_expression_list {
	my ($self, $expression_list) = @_;

	my @res;
	foreach my $expression (0 .. $#$expression_list - 1) {
		push @res, ($self->interpret_expression($expression))[0];
	}
	push @res, $self->interpret_expression($expression_list->[-1]);

	return @res
}

sub interpret_expression {
	my ($self, $expression) = @_;

	my @res;
	if ($expression->{type} eq 'nil_constant') {
		push @res, [ nil => undef ];
	} elsif ($expression->{type} eq 'bool_constant') {
		push @res, [ bool => $expression->{value} ];
	} elsif ($expression->{type} eq 'numeric_constant') {
		push @res, [ number => $expression->{value} ];
	} elsif ($expression->{type} eq 'string_constant') {
		push @res, [ string => $expression->{value} ];
	} elsif ($expression->{type} eq 'function_expression') {
		# TODO: closures
		push @res, [ function => { args_list => $expression->{args_list}, block => $expression->{block} } ];
	} else {
		die "unimplemented expression type $expression->{type}";
	}

	return @res
}



1;


