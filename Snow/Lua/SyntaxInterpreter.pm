package Snow::Lua::SyntaxInterpreter;
use parent 'Snow::Lua::SyntaxParser';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;
use Carp;



our $lua_nil_constant = [ nil => undef ];



sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);

	$self->{global_scope} = {};
	$self->{local_scope_stack} = []; # local scopes are stored in reverse order in this stack (0 being the deepest, -1 being the shallowest)
	$self->{current_local_scope} = undef;

	return $self;
}


sub interpret {
	my ($self) = @_;
	my @res = $self->interpret_block($self->{syntax_tree});
	say "main returned: ", Dumper @res;
}

sub interpret_block {
	my ($self, $block) = @_;

	unshift @{$self->{local_scope_stack}}, $self->{current_local_scope} if defined $self->{current_local_scope};
	$self->{current_local_scope} = {};

	my @res;

	my $i = 0;
	while ($i < @$block) {
		my $statement = $block->[$i];
		if ($statement->{type} eq 'return_statement') {
			@res = (return => [ $self->interpret_expression_list($statement->{expression_list}) ]);
			last
		} elsif ($statement->{type} eq 'variable_declaration_statement') {
			if (defined $statement->{expression_list}) {
				my @data = $self->interpret_expression_list($statement->{expression_list});
				foreach my $name (@{$statement->{names_list}}) {
					$self->{current_local_scope}{$name} = shift @data // $lua_nil_constant;
				}
			} else {
				foreach my $name (@{$statement->{names_list}}) {
					$self->{current_local_scope}{$name} = $lua_nil_constant;
				}
			}
		} else {
			die "unimplemented statement type $statement->{type}";
		}
		$i++;
	}

	# say Dumper $self->{current_local_scope};
	$self->{current_local_scope} = shift @{$self->{local_scope_stack}} if @{$self->{local_scope_stack}};

	return @res
}

sub interpret_expression_list {
	my ($self, $expression_list) = @_;

	my @res;
	foreach my $i (0 .. $#$expression_list - 1) {
		push @res, ($self->interpret_expression($expression_list->[$i]))[0];
	}
	push @res, $self->interpret_expression($expression_list->[-1]);

	return @res
}

sub interpret_expression {
	my ($self, $expression) = @_;

	my @res;
	if ($expression->{type} eq 'nil_constant') {
		push @res, $lua_nil_constant;
	} elsif ($expression->{type} eq 'bool_constant') {
		push @res, [ bool => $expression->{value} ];
	} elsif ($expression->{type} eq 'numeric_constant') {
		push @res, [ number => $expression->{value} ];
	} elsif ($expression->{type} eq 'string_constant') {
		push @res, [ string => $expression->{value} ];
	} elsif ($expression->{type} eq 'function_expression') {
		# TODO: closures
		push @res, [ function => { args_list => $expression->{args_list}, block => $expression->{block} } ];
	} elsif ($expression->{type} eq 'identifier_expression') {
		push @res, $self->get_variable($expression->{identifier});
	} else {
		die "unimplemented expression type $expression->{type}";
	}

	return @res
}



sub get_variable {
	my ($self, $identifier) = @_;

	return $self->{current_local_scope}{$identifier} if defined $self->{current_local_scope} and exists $self->{current_local_scope}{$identifier};

	foreach my $i (0 .. $#{$self->{local_scope_stack}}) {
		return $self->{local_scope_stack}[$i]{$identifier} if exists $self->{local_scope_stack}[$i]{$identifier};
	}

	return $self->{global_scope}{$identifier} // $lua_nil_constant
}


1;


