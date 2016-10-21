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
		say 
			# "print: ", 
			join "\t", map to_string($_)->[1], @args;
		return return =>
	} } ];
	$self->{global_scope}{dump} = [ function => { is_native => 1, function => sub {
		my ($self, @args) = @_;
		say Dumper \@args;
		return return =>
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
	my ($self, $bytecode_chunk, @args) = @_;

	my $i = 0;

	my @saved_stacks;
	my @stack = @args;
	my @locals;

	while ($i < @$bytecode_chunk) {
		my $op = $bytecode_chunk->[$i++];
		my $arg = $bytecode_chunk->[$i++];

		# say "\t", join ', ', map '{' . $self->dump_stack( $_ ) . '}', @saved_stacks, \@stack;
		# # say "\t", $self->dump_stack( \@stack );
		# say "$op => ", $arg // '';

		if ($op eq 'ps') {
			push @stack, $arg;
		} elsif ($op eq 'bs') {
			push @stack, $stack[-1];
		} elsif ($op eq 'ss') {
			push @saved_stacks, [ @stack ];
			@stack = ();
		} elsif ($op eq 'cs') {
			push @saved_stacks, [ @stack ];
		} elsif ($op eq 'rs') {
			@stack = reverse @stack;
		} elsif ($op eq 'ts') {
			@stack = @stack[0 .. ($arg - 1)];
		} elsif ($op eq 'ds') {
			@stack = @{pop @saved_stacks};
		# } elsif ($op eq 'ls') {
		# 	@stack = (@{pop @saved_stacks}, @stack[0 .. ($arg - 1)]);
		} elsif ($op eq 'ms') {
			@stack = (@{pop @saved_stacks}, @stack);

		} elsif ($op eq 'lg') {
			push @stack, $self->{global_scope}{$arg} // $lua_nil_constant;
		} elsif ($op eq 'sg') {
			$self->{global_scope}{$arg} = pop @stack // $lua_nil_constant;
		} elsif ($op eq 'll') {
			push @stack, $locals[$arg];
		} elsif ($op eq 'sl') {
			$locals[$arg] = pop @stack // $lua_nil_constant;
		} elsif ($op eq 'yl') {
			@locals[$arg .. $arg + $#stack] = @stack;
		} elsif ($op eq 'xl') {
			@locals = ($lua_nil_constant) x $arg;
		# } elsif ($op eq 'tl') {
		# 	@locals = @locals[0 .. (-$arg - 1)];

		} elsif ($op eq 'fc') {
			my $function = shift @stack;
			return error => "attempt to call value type $function->[0]" if $function->[0] ne 'function';
			my ($status, @data);
			if ($function->[1]{is_native}) {
				($status, @data) = $function->[1]{function}->($self, @stack);
			} else {
				($status, @data) = $self->execute_bytecode($function->[1]{chunk}, @stack);
			}
			return $status, @data if $status ne 'return';
			@stack = @data;
			# @stack = (@{pop @saved_stacks}, @data);
			# push @stack, @data;
		} elsif ($op eq 'fj') {
			$i += $arg if (pop @stack)->[1] == 0;
		} elsif ($op eq 'tj') {
			$i += $arg if (pop @stack)->[1] == 1;
		} elsif ($op eq 'aj') {
			$i += $arg;
		} elsif ($op eq 'lv') {
			return return => @stack

		} elsif ($op eq 'fr') {
			if ($stack[-1][1] > 0) {
				push @stack, [ bool => $locals[$arg][1] <= $stack[-2][1] ];
			} else {
				push @stack, [ bool => $locals[$arg][1] >= $stack[-2][1] ];
			}

		} elsif ($op eq 'bt') {
			push @stack, $self->cast_bool(pop @stack);
			
		} elsif ($op eq 'un') {
			if ($arg eq 'not') {
				push @stack, [ bool => not $self->cast_bool(pop @stack)->[1] ];
			} elsif ($arg eq '#') {
				... # unary table length
			} elsif ($arg eq '-') {
				my $val = pop @stack;
				my $num = $self->cast_number($val);
				return error => "attempt to perform arithmetic on a $val->[0] value" if $num == $lua_nil_constant;
				push @stack, [ number => -$num->[1] ];
			} elsif ($arg eq '~') {
				... # unary bitwise not
			} else {
				die "unimplemented bytecode unary operation type $arg";
			}

		} elsif ($op eq 'co') {
			push @stack, [ table => { _metatable => undef, _index => 1, } ];
		} elsif ($op eq 'io') {
			my $val = pop @stack;
			$stack[0][1]{"string_$arg"} = $val;
		} elsif ($op eq 'eo') {
			my $val = pop @stack;
			my $key = pop @stack;
			return error => "table key is nil" if $val == $lua_nil_constant;
			$stack[0][1]{"$key->[0]_$key->[1]"} = $val;
		} elsif ($op eq 'ao') {
			my $val = pop @stack;
			$stack[0][1]{"number_" . $stack[0][1]{_index}++} = $val;
		} elsif ($op eq 'lo') {
			my $obj = pop @stack;
			return error => "attempt to access non-object type $obj->[0]" unless $obj->[0] eq 'table';
			push @stack, $obj->[1]{"string_$arg"} // $lua_nil_constant;
		} elsif ($op eq 'so') {
			my $obj = pop @stack;
			my $val = pop @stack;
			return error => "attempt to store in non-object type $obj->[0]" unless $obj->[0] eq 'table';
			$obj->[1]{"string_$arg"} = $val;
		} elsif ($op eq 'vo') {
			my $key = pop @stack;
			my $obj = pop @stack;
			my $val = pop @stack;
			return error => "attempt to store in non-object type $obj->[0]" unless $obj->[0] eq 'table';
			$obj->[1]{"$key->[0]_$key->[1]"} = $val;


		} elsif ($op eq 'bn') {
			if ($arg eq 'or') {
				...
			} elsif ($arg eq 'and') {
				...
			} elsif ($arg eq '<') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1->[0] eq 'number' and $val2->[0] eq 'number') { push @stack, [ bool => $val1->[1] < $val2->[1] ] }
				elsif ($val1->[0] eq 'string' and $val2->[0] eq 'string') { push @stack, [ bool => $val1->[1] lt $val2->[1] ] }
				else { return error => "attempt to compare $val1->[0] with $val2->[0]" }
			} elsif ($arg eq '>') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1->[0] eq 'number' and $val2->[0] eq 'number') { push @stack, [ bool => $val1->[1] > $val2->[1] ] }
				elsif ($val1->[0] eq 'string' and $val2->[0] eq 'string') { push @stack, [ bool => $val1->[1] gt $val2->[1] ] }
				else { return error => "attempt to compare $val1->[0] with $val2->[0]" }
			} elsif ($arg eq '<=') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1->[0] eq 'number' and $val2->[0] eq 'number') { push @stack, [ bool => $val1->[1] <= $val2->[1] ] }
				elsif ($val1->[0] eq 'string' and $val2->[0] eq 'string') { push @stack, [ bool => $val1->[1] le $val2->[1] ] }
				else { return error => "attempt to compare $val1->[0] with $val2->[0]" }
			} elsif ($arg eq '>=') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1->[0] eq 'number' and $val2->[0] eq 'number') { push @stack, [ bool => $val1->[1] >= $val2->[1] ] }
				elsif ($val1->[0] eq 'string' and $val2->[0] eq 'string') { push @stack, [ bool => $val1->[1] ge $val2->[1] ] }
				else { return error => "attempt to compare $val1->[0] with $val2->[0]" }
			} elsif ($arg eq '~=') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1 == $val2) { push @stack, [ bool => 0 ] }
				elsif ($val1->[0] eq $val2->[0] and $val1->[0] eq 'string') { push @stack, [ bool => $val1->[1] ne $val2->[1] ] }
				elsif ($val1->[0] eq $val2->[0]) { push @stack, [ bool => $val1->[1] != $val2->[1] ] }
				else { push @stack, [ bool => 1 ] }
			} elsif ($arg eq '==') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1 == $val2) { push @stack, [ bool => 1 ] }
				elsif ($val1->[0] eq $val2->[0] and $val1->[0] eq 'string') { push @stack, [ bool => $val1->[1] eq $val2->[1] ] }
				elsif ($val1->[0] eq $val2->[0]) { push @stack, [ bool => $val1->[1] == $val2->[1] ] }
				else { push @stack, [ bool => 0 ] }
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


sub dump_stack {
	my ($self, $stack) = @_;
	return join '', map "[$_->[0]:$_->[1]]", @$stack;
}


sub to_string {
	my ($val) = @_;
	if ($val == $lua_nil_constant) {
		return [ string => 'nil' ];
	} elsif ($val->[0] eq 'bool') {
		return [ string => $val->[1] ? 'true' : 'false' ];
	} elsif ($val->[0] eq 'number' or $val->[0] eq 'string') {
		return [ string => "$val->[1]" ];
	} elsif ($val->[0] eq 'table') {
		return [ string => "$val->[1]" =~ s/^HASH\((.*)\)$/table: $1/r ];
	} elsif ($val->[0] eq 'function') {
		return [ string => "$val->[1]" =~ s/^HASH\((.*)\)$/function: $1/r ];
	} else {
		die "what $val->[0]";
	}
}


1;
