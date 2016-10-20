package Snow::Lua::BytecodeInterpreter;
use parent 'Snow::Lua::Bytecode';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;
use Carp;




our $lua_nil_constant = $Snow::Lua::Bytecode::lua_nil_constant;




sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);

	$self->initialize_runtime;

	$self->load_libraries;

	return $self;
}


sub initialize_runtime {
	my ($self) = @_;
	$self->{global_scope} = {};
	$self->{local_scope_stack} = []; # local scopes are stored in reverse order in this stack (0 being the deepest, -1 being the shallowest)
	$self->{current_local_scope} = undef;

}

sub load_libraries {
	my ($self) = @_;

	$self->{global_scope}{print} = [ function => { is_native => 1, function => sub {
		my ($self, @args) = @_;
		say "print: ", join "\t", map "$_->[1]", @args;
		return return => $lua_nil_constant
	} } ];
}



sub execute {
	my ($self, $bytecode_chunk) = @_;
	$bytecode_chunk = $bytecode_chunk // $self->{bytecode_chunk};

	my ($status, @data) = $self->execute_bytecode($bytecode_chunk);

	if ($status eq 'error') {
		warn "lua runtime error: @data";
	}
}



sub execute_bytecode {
	my ($self, $bytecode_chunk) = @_;

	my $i = 0;

	my @saved_stacks;
	my @stack;
	my @locals;

	while ($i < @$bytecode_chunk) {
		my $op = $bytecode_chunk->[$i++];
		my $arg = $bytecode_chunk->[$i++];

		# say Dumper \@saved_stacks;
		# say Dumper \@stack;
		# say "$op";

		if ($op eq 'bt') {
			push @stack, $self->cast_bool(pop @stack);
		} elsif ($op eq 'ps') {
			push @stack, $arg;
		} elsif ($op eq 'ss') {
			push @saved_stacks, [ @stack ];
			@stack = ();
		} elsif ($op eq 'rs') {
			@stack = reverse @stack;
		} elsif ($op eq 'ts') {
			@stack = @stack[0 .. ($arg - 1)];
		} elsif ($op eq 'ds') {
			# say Dumper [ @stack[0 .. $arg] ];
			@stack = @{pop @saved_stacks};
		} elsif ($op eq 'ls') {
			# say Dumper [ @stack[0 .. $arg] ];
			@stack = (@{pop @saved_stacks}, @stack[0 .. ($arg - 1)]);

		} elsif ($op eq 'lg') {
			push @stack, $self->{global_scope}{$arg} // $lua_nil_constant;
		} elsif ($op eq 'sg') {
			$self->{global_scope}{$arg} = pop @stack // $lua_nil_constant;
		} elsif ($op eq 'll') {
			push @stack, $locals[$arg];
		} elsif ($op eq 'sl') {
			$locals[$arg] = pop @stack // $lua_nil_constant;
		} elsif ($op eq 'xl') {
			@locals = ($lua_nil_constant) x $arg;
		# } elsif ($op eq 'tl') {
		# 	@locals = @locals[0 .. (-$arg - 1)];

		} elsif ($op eq 'fc') {
			my @args = @stack;
			@stack = @{pop @saved_stacks};
			my $function = pop @stack;
			return error => "attempt to call value type $function->[0]" if $function->[0] ne 'function';
			my ($status, @data) = $function->[1]{function}->($self, @args);
			return $status, @data if $status ne 'return';
			push @stack, @data;
		} elsif ($op eq 'fj') {
			$i += $arg if (pop @stack)->[1] == 0;
		} elsif ($op eq 'tj') {
			$i += $arg if (pop @stack)->[1] == 1;
		} elsif ($op eq 'aj') {
			$i += $arg;
		} elsif ($op eq 'rt') {
			return return => @stack

		} elsif ($op eq 'un') {
			if ($arg eq 'not') {
				push @stack, [ bool => not $self->cast_bool(pop @stack)->[1] ];
			} elsif ($arg eq '#') {
				... # unary table length
			} elsif ($arg eq '-') {
				... # unary numeric negation
			} elsif ($arg eq '~') {
				... # unary bitwise not
			} else {
				die "unimplemented bytecode unary operation type $arg";
			}

		} elsif ($op eq 'bn') {
			if ($arg eq 'or') {
				...
			} elsif ($arg eq 'and') {
				...
			} elsif ($arg eq '<') {
				...
			} elsif ($arg eq '>') {
				...
			} elsif ($arg eq '<=') {
				...
			} elsif ($arg eq '>=') {
				...
			} elsif ($arg eq '~=') {
				...
			} elsif ($arg eq '==') {
				...
			} elsif ($arg eq '|') {
				...
			} elsif ($arg eq '~') {
				...
			} elsif ($arg eq '&') {
				...
			} elsif ($arg eq '<<') {
				...
			} elsif ($arg eq '>>') {
				...
			} elsif ($arg eq '..') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				return error => "attempt to concatenate a $val1->[0] value" if $val1->[0] ne 'string' and $val1->[0] ne 'number';
				return error => "attempt to concatenate a $val2->[0] value" if $val2->[0] ne 'string' and $val2->[0] ne 'number';
				push @stack, [ string => $val1->[1] . $val2->[1] ];
			} elsif ($arg eq '+') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				my $num1 = $self->cast_number($val1);
				my $num2 = $self->cast_number($val2);
				return error => "attempt to perform arithmetic on a $val1->[0] value" if $num1 == $lua_nil_constant;
				return error => "attempt to perform arithmetic on a $val2->[0] value" if $num2 == $lua_nil_constant;
				push @stack, [ number => $num1->[1] + $num2->[1] ];
			} elsif ($arg eq '-') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				my $num1 = $self->cast_number($val1);
				my $num2 = $self->cast_number($val2);
				return error => "attempt to perform arithmetic on a $val1->[0] value" if $num1 == $lua_nil_constant;
				return error => "attempt to perform arithmetic on a $val2->[0] value" if $num2 == $lua_nil_constant;
				push @stack, [ number => $num1->[1] - $num2->[1] ];
			} elsif ($arg eq '*') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				my $num1 = $self->cast_number($val1);
				my $num2 = $self->cast_number($val2);
				return error => "attempt to perform arithmetic on a $val1->[0] value" if $num1 == $lua_nil_constant;
				return error => "attempt to perform arithmetic on a $val2->[0] value" if $num2 == $lua_nil_constant;
				push @stack, [ number => $num1->[1] * $num2->[1] ];
			} elsif ($arg eq '/') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				my $num1 = $self->cast_number($val1);
				my $num2 = $self->cast_number($val2);
				return error => "attempt to perform arithmetic on a $val1->[0] value" if $num1 == $lua_nil_constant;
				return error => "attempt to perform arithmetic on a $val2->[0] value" if $num2 == $lua_nil_constant;
				push @stack, [ number => $num1->[1] / $num2->[1] ];
			} elsif ($arg eq '//') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				my $num1 = $self->cast_number($val1);
				my $num2 = $self->cast_number($val2);
				return error => "attempt to perform arithmetic on a $val1->[0] value" if $num1 == $lua_nil_constant;
				return error => "attempt to perform arithmetic on a $val2->[0] value" if $num2 == $lua_nil_constant;
				push @stack, [ number => int ($num1->[1] / $num2->[1]) ];
			} elsif ($arg eq '%') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				my $num1 = $self->cast_number($val1);
				my $num2 = $self->cast_number($val2);
				return error => "attempt to perform arithmetic on a $val1->[0] value" if $num1 == $lua_nil_constant;
				return error => "attempt to perform arithmetic on a $val2->[0] value" if $num2 == $lua_nil_constant;
				push @stack, [ number => $num1->[1] % $num2->[1] ];
			} else {
				die "unimplemented bytecode unary operation type $arg";
			}

		} else {
			die "unimplemented bytecode type $op";
		}
	}
}




sub cast_bool {
	my ($self, $val) = @_;
	if ($val == $lua_nil_constant) {
		return [ bool => 0 ]
	} elsif ($val->[0] eq 'bool') {
		return $val
	} else {
		return [ bool => 1 ]
	}
}



sub cast_number {
	my ($self, $val) = @_;
	if ($val->[0] eq 'number') {
		return $val
	} elsif ($val->[0] eq 'string' and $val->[1] =~ /^(\d+)$/) {
		return [ number => $1 ]
	} else {
		return $lua_nil_constant
	}
}



1;
