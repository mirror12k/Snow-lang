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

	$self->execute_bytecode($bytecode_chunk);
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

		if ($op eq 'ps') {
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
		} elsif ($op eq 'sl') {
			$locals[$arg] = pop @stack // $lua_nil_constant;
		} elsif ($op eq 'll') {
			push @stack, $locals[$arg];
		} elsif ($op eq 'xl') {
			push @locals, $lua_nil_constant foreach 1 .. $arg;
		} elsif ($op eq 'tl') {
			@locals = @locals[0 .. (-$arg - 1)];
		} elsif ($op eq 'fc') {
			my @args = @stack;
			@stack = @{pop @saved_stacks};
			my $function = pop @stack;
			return error => "attempt to call value type $function->[0]" if $function->[0] ne 'function';
			my ($status, @data) = $function->[1]{function}->($self, @args);
			return $status, @data if $status ne 'return';
			push @stack, @data
		} else {
			die "unimplemented bytecode type $op";
		}
	}
}



1;
