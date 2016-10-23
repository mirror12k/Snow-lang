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


# helper to create native functions
sub lua_native_function (&) {
	my ($fun) = @_;
	return [ function => { is_native => 1, function => $fun } ]
}

sub load_libraries {
	my ($self) = @_;

	$self->{global_scope}{print} = lua_native_function {
		my ($self, @args) = @_;
		say 
			join "\t", map to_string($_)->[1], @args;
		return return =>
	};
	my $ipairs_iterator = lua_native_function {
		my ($self, $t, $index) = @_;
		$index = $index->[1] + 1;
		return return => $lua_nil_constant
			unless exists $t->[1]{"number_$index"} and defined $t->[1]{"number_$index"} and $t->[1]{"number_$index"} != $lua_nil_constant;
		return return => [ number => $index ], $t->[1]{"number_$index"}
	};
	$self->{global_scope}{ipairs} = lua_native_function {
		my ($self, $t) = @_;
		return error => "bad argument #1 to ipairs (table expected)" unless defined $t and $t->[0] eq 'table';

		return return => $ipairs_iterator, $t, [ number => 0 ]
	};
	# my $pairs_iterator = lua_native_function {
	# 	my ($self, $t, $index) = @_;
	# 	my ($k, $v) = each $t->[1];
	# 	while (defined $k and ($k eq '_metatable' or $k eq '_index')) {
	# 		($k, $v) = each $t->[1];
	# 	}
	# 	return return => $lua_nil_constant unless defined $k;
	# 	return return => [ string => $k ], $v
	# };
	# $self->{global_scope}{pairs} = lua_native_function {
	# 	my ($self, $t) = @_;
	# 	return error => "bad argument #1 to type function (table expected)" unless defined $t and $t->[0] eq 'table';

	# 	return return => $pairs_iterator, $t, $lua_nil_constant
	# };
	$self->{global_scope}{type} = lua_native_function {
		my ($self, $arg) = @_;
		return error => "bad argument #1 to type (value expected)" unless defined $arg;
		return return => [ string => $arg->[0] ]
	};
	$self->{global_scope}{dump} = lua_native_function {
		my ($self, @args) = @_;
		say Dumper \@args;
		return return =>
	};

	$self->{global_scope}{coroutine} = [ table => {
			_metatable => undef,
			string_running => lua_native_function {
				my ($self, @args) = @_;
				return return => $self->{running_coroutine}, [ boolean => $self->{running_coroutine}[1]{is_main} ]
			},
			string_create => lua_native_function {
				my ($self, $f) = @_;
				return error => "bad argument #1 to coroutine.create (function expected)" unless defined $f and $f->[0] eq 'function';
				return return => $self->create_coroutine($f->[1], 0)
			},
			string_resume => lua_native_function {
				my ($self, $th, @args) = @_;
				return error => "bad argument #1 to coroutine.resume (thread expected)" unless defined $th and $th->[0] eq 'thread';
				return resume => $th
			},
			string_status => lua_native_function {
				my ($self, $th) = @_;
				return error => "bad argument #1 to coroutine.resume (thread expected)" unless defined $th and $th->[0] eq 'thread';
				return return => [ string => $th->[1]{status} ]
			},
	} ];
}



sub execute {
	my ($self) = @_;

	$self->{main_coroutine} = $self->create_coroutine($self->{bytecode_chunk}, 1);

	my @coroutine_stack;
	my $current_coroutine = $self->{main_coroutine};
	while (defined $current_coroutine) {
		my ($status, @data) = $self->run_coroutine($current_coroutine);
		if ($status eq 'resume') {
			# warn "resuming coroutine";
			my $new_coroutine = shift @data;
			my @arg_stack = @{shift @data};
			$new_coroutine->[1]{stack} = [ @arg_stack[ 1 .. $#arg_stack ] ];
			$current_coroutine->[1]{call_frames} = shift @data;
			$current_coroutine->[1]{saved_stacks} = shift @data;
			$current_coroutine->[1]{stack} = [];
			push @coroutine_stack, $current_coroutine;
			$current_coroutine->[1]{status} = 'normal';
			$current_coroutine = $new_coroutine;

		} elsif ($status eq 'error') {
			my $error = "lua: $data[0]\n" . join ("\n", @data[1 .. $#data]) . "\n";
			warn $error unless @coroutine_stack;
			$current_coroutine->[1]{status} = 'dead';
			$current_coroutine = pop @coroutine_stack;
			$current_coroutine->[1]{stack} = [ [ boolean => 0 ], [ string => $error ] ] if defined $current_coroutine;
		} elsif ($status eq 'return') {
			$current_coroutine->[1]{status} = 'dead';
			$current_coroutine = pop @coroutine_stack;
			$current_coroutine->[1]{stack} = [ [ boolean => 1 ], @data ] if defined $current_coroutine;
		}
	}
}

sub create_coroutine {
	my ($self, $bytecode_chunk, $is_main) = @_;
	return [ thread => { chunk => $bytecode_chunk, is_main => $is_main, status => 'suspended', stack => [] } ]
}

sub run_coroutine {
	my ($self, $coroutine) = @_;
	$self->{running_coroutine} = $coroutine;
	$coroutine->[1]{status} = 'running';
	my @args;
	@args = ($coroutine->[1]{call_frames}, $coroutine->[1]{saved_stacks}) if defined $coroutine->[1]{call_frames};
	# warn "debug dump: ", Dumper $coroutine->[1];
	return $self->execute_bytecode_chunk($coroutine->[1]{chunk}, $coroutine->[1]{stack}, @args);
}


sub execute_bytecode_chunk {
	my ($self, $bytecode_chunk, $stack_load, @reload) = @_;

	# data persistent across frames
	my @call_frames;
	my @saved_stacks;
	my @stack = @$stack_load;
	if (@reload) {
		@call_frames = @{shift @reload};
		@saved_stacks = @{shift @reload};

		push @call_frames, { dummy => 1 };
		goto EXIT_FRAME;
	}

	INIT_FRAME:

	# data localized to a single stack frame
	my $vararg = [];
	my $locals = [];
	my $i = 0;

	push @call_frames, [ $bytecode_chunk, $locals, $vararg, $i ];
	
	RUN_BYTECODE_CHUNK:



	# this localized data is easier to load here than earlier
	my $local_closures = $bytecode_chunk->{closures};
	my $bytecode = $bytecode_chunk->{chunk};

	# warn "running chunk:\n", $self->dump_bytecode($bytecode); # DEBUG RUNTIME

	while ($i < @$bytecode) {
		my $op = $bytecode->[$i++];
		my $arg = $bytecode->[$i++];

		# say "\t", join ', ', map '{' . $self->dump_stack( $_ ) . '}', @saved_stacks, \@stack; # DEBUG RUNTIME
		# say "$op => ", $arg // ''; # DEBUG RUNTIME

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
			@stack = map $_ // $lua_nil_constant, @stack[0 .. ($arg - 1)];
		} elsif ($op eq 'ds') {
			@stack = @{pop @saved_stacks};
		} elsif ($op eq 'es') {
			@stack = ();
		# } elsif ($op eq 'ls') {
		# 	@stack = (@{pop @saved_stacks}, @stack[0 .. ($arg - 1)]);
		} elsif ($op eq 'ms') {
			@stack = (@{pop @saved_stacks}, @stack);

		} elsif ($op eq 'lg') {
			push @stack, $self->{global_scope}{$arg} // $lua_nil_constant;
		} elsif ($op eq 'sg') {
			$self->{global_scope}{$arg} = pop @stack // $lua_nil_constant;

		} elsif ($op eq 'll') {
			push @stack, $locals->[$arg];
		} elsif ($op eq 'sl') {
			$locals->[$arg] = pop @stack // $lua_nil_constant;
		} elsif ($op eq 'yl') {
			@$locals[$arg .. $arg + $#stack] = @stack;
		} elsif ($op eq 'xl') {
			@$locals = ($lua_nil_constant) x $arg;
		# } elsif ($op eq 'tl') {
		# 	@locals = @locals[0 .. (-$arg - 1)];

		} elsif ($op eq 'lc') {
			push @stack, ${$local_closures->[$arg]};
		} elsif ($op eq 'sc') {
			${$local_closures->[$arg]} = pop @stack // $lua_nil_constant;

		} elsif ($op eq 'sv') {
			@$vararg = @stack[$arg .. $#stack];
		} elsif ($op eq 'lv') {
			push @stack, @$vararg;
		} elsif ($op eq 'dv') {
			push @stack, $vararg->[0] // $lua_nil_constant;

		} elsif ($op eq 'fj') {
			$i += $arg if (pop @stack)->[1] == 0;
		} elsif ($op eq 'tj') {
			$i += $arg if (pop @stack)->[1] == 1;
		} elsif ($op eq 'aj') {
			$i += $arg;
		} elsif ($op eq 'cf') {
			my $function = shift @stack;
			# say "calling function $function->[0] : $function->[1]"; # DEBUG RUNTIME
			$call_frames[-1][-1] = $i;
			return error => "attempt to call value type $function->[0]", $self->generate_lua_error_trace(\@call_frames) if $function->[0] ne 'function';

			if ($function->[1]{is_native}) {
				my ($status, @data) = $function->[1]{function}->($self, @stack);
				# say "functon returned $status => @data"; #DEBUG RUNTIME
				return $status, $data[0], \@stack, \@call_frames, \@saved_stacks if $status eq 'resume';
				return $status, @data if $status ne 'return';
				@stack = @data;
			} else {
				$bytecode_chunk = $function->[1];
				goto INIT_FRAME;
				# ($status, @data) = $self->execute_bytecode_chunk($function->[1], @stack);
			}
			# @stack = map $_ // $lua_nil_constant, @stack[0 .. ($arg - 1)] if defined $arg;
		} elsif ($op eq 'pf') {
			# say "closure_list ", Dumper $arg->[1]{closure_list};
			my $closures = [ map { /^c(\d+)$/ ? $local_closures->[$1] : \($locals->[$_]) } @{$arg->[1]{closure_list}} ];
			# say "closures: ", Dumper $closures;
			push @stack, [ function => {
				chunk => $arg->[1]{chunk},
				sourcefile => $arg->[1]{sourcefile},
				line_number_table => $arg->[1]{line_number_table},
				closures => $closures,
			} ];
		} elsif ($op eq 'lf') {
			goto EXIT_FRAME;
			# return return => @stack

		} elsif ($op eq 'fr') {
			if ($stack[-1][1] > 0) {
				push @stack, [ boolean => $locals->[$arg][1] <= $stack[-2][1] ];
			} else {
				push @stack, [ boolean => $locals->[$arg][1] >= $stack[-2][1] ];
			}

		} elsif ($op eq 'bt') {
			push @stack, $self->cast_boolean(pop @stack);
			
		} elsif ($op eq 'un') {
			if ($arg eq 'not') {
				push @stack, [ boolean => not $self->cast_boolean(pop @stack)->[1] ];
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
			$stack[-1][1]{"string_$arg"} = $val;
		} elsif ($op eq 'eo') {
			my $val = pop @stack;
			my $key = pop @stack;
			return error => "table key is nil" if $val == $lua_nil_constant;
			$stack[-1][1]{"$key->[0]_$key->[1]"} = $val;
		} elsif ($op eq 'ao') {
			my $val = pop @stack;
			$stack[-1][1]{"number_" . $stack[-1][1]{_index}++} = $val;
		} elsif ($op eq 'lo') {
			my $obj = pop @stack;
			return error => "attempt to access non-object type $obj->[0]" unless $obj->[0] eq 'table';
			push @stack, exists $obj->[1]{"string_$arg"} ? $obj->[1]{"string_$arg"} : $lua_nil_constant;
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
		} elsif ($op eq 'mo') {
			my $key = pop @stack;
			my $obj = pop @stack;
			return error => "attempt to access in non-object type $obj->[0]" unless $obj->[0] eq 'table';
			push @stack, exists $obj->[1]{"$key->[0]_$key->[1]"} ? $obj->[1]{"$key->[0]_$key->[1]"} : $lua_nil_constant;


		} elsif ($op eq 'bn') {
			if ($arg eq 'or') {
				...
			} elsif ($arg eq 'and') {
				...
			} elsif ($arg eq '<') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1->[0] eq 'number' and $val2->[0] eq 'number') { push @stack, [ boolean => $val1->[1] < $val2->[1] ] }
				elsif ($val1->[0] eq 'string' and $val2->[0] eq 'string') { push @stack, [ boolean => $val1->[1] lt $val2->[1] ] }
				else { return error => "attempt to compare $val1->[0] with $val2->[0]" }
			} elsif ($arg eq '>') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1->[0] eq 'number' and $val2->[0] eq 'number') { push @stack, [ boolean => $val1->[1] > $val2->[1] ] }
				elsif ($val1->[0] eq 'string' and $val2->[0] eq 'string') { push @stack, [ boolean => $val1->[1] gt $val2->[1] ] }
				else { return error => "attempt to compare $val1->[0] with $val2->[0]" }
			} elsif ($arg eq '<=') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1->[0] eq 'number' and $val2->[0] eq 'number') { push @stack, [ boolean => $val1->[1] <= $val2->[1] ] }
				elsif ($val1->[0] eq 'string' and $val2->[0] eq 'string') { push @stack, [ boolean => $val1->[1] le $val2->[1] ] }
				else { return error => "attempt to compare $val1->[0] with $val2->[0]" }
			} elsif ($arg eq '>=') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1->[0] eq 'number' and $val2->[0] eq 'number') { push @stack, [ boolean => $val1->[1] >= $val2->[1] ] }
				elsif ($val1->[0] eq 'string' and $val2->[0] eq 'string') { push @stack, [ boolean => $val1->[1] ge $val2->[1] ] }
				else { return error => "attempt to compare $val1->[0] with $val2->[0]" }
			} elsif ($arg eq '~=') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1 == $val2) { push @stack, [ boolean => 0 ] }
				elsif ($val1->[0] eq $val2->[0] and $val1->[0] eq 'string') { push @stack, [ boolean => $val1->[1] ne $val2->[1] ] }
				elsif ($val1->[0] eq $val2->[0]) { push @stack, [ boolean => $val1->[1] != $val2->[1] ] }
				else { push @stack, [ boolean => 1 ] }
			} elsif ($arg eq '==') {
				my $val2 = pop @stack;
				my $val1 = pop @stack;
				if ($val1 == $val2) { push @stack, [ boolean => 1 ] }
				elsif ($val1->[0] eq $val2->[0] and $val1->[0] eq 'string') { push @stack, [ boolean => $val1->[1] eq $val2->[1] ] }
				elsif ($val1->[0] eq $val2->[0]) { push @stack, [ boolean => $val1->[1] == $val2->[1] ] }
				else { push @stack, [ boolean => 0 ] }
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

	EXIT_FRAME:
	# say "debug exit frame"; # DEBUG RUNTIME
	pop @call_frames;
	return return => @stack unless @call_frames;

	($bytecode_chunk, $locals, $vararg, $i) = @{$call_frames[-1]};
	goto RUN_BYTECODE_CHUNK
}




sub cast_boolean {
	my ($self, $val) = @_;
	if ($val == $lua_nil_constant) {
		return [ boolean => 0 ]
	} elsif ($val->[0] eq 'boolean') {
		return $val
	} else {
		return [ boolean => 1 ]
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
	} elsif ($val->[0] eq 'boolean') {
		return [ string => $val->[1] ? 'true' : 'false' ];
	} elsif ($val->[0] eq 'number' or $val->[0] eq 'string') {
		return [ string => "$val->[1]" ];
	} elsif ($val->[0] eq 'table') {
		return [ string => "$val->[1]" =~ s/^HASH\((.*)\)$/table: $1/r ];
	} elsif ($val->[0] eq 'function') {
		return [ string => "$val->[1]" =~ s/^HASH\((.*)\)$/function: $1/r ];
	} elsif ($val->[0] eq 'thread') {
		return [ string => "$val->[1]" =~ s/^HASH\((.*)\)$/thread: $1/r ];
	} else {
		die "what $val->[0]";
	}
}

sub generate_lua_error_trace {
	my ($self, $call_frames) = @_;

	my @trace = ("stack traceback:");
	foreach my $frame (reverse @$call_frames) {
		push @trace, "\t$frame->[0]{sourcefile}:" . $self->get_line_number_from_offset($frame->[0], $frame->[-1] - 2);
	}
	return @trace;
}

sub get_line_number_from_offset {
	my ($self, $chunk, $offset) = @_;
	my @line_number_table = @{$chunk->{line_number_table}};
	my $best = undef;
	while (@line_number_table) {
		my $i = shift @line_number_table;
		my $line_number = shift @line_number_table;
		last if $i > $offset;
		$best = $line_number;
	}
	return $best;
}


1;
