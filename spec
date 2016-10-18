


snow language spec draft v0.2
	compiles straight to lua code
	most syntax taken from lua
	features:
		.. operator merged with +
			(typed variables allow the compiler to discern the two)
		self-referential operators
			s += "_suffix"
				becomes
					s = s + "_suffix"
			n++
				becomes
					n = n + 1

			+= -= *= /= %= ^= ++ --

		tables declared via []
			tables may only act as hash-tables or as array-tables, determined by how it is declared and how it is assigned to a variable
			arrays:
				[ 5,4,3 ]
			tables:
				[ a => 5, b => 15, c => -10 ]

		staticly typed variables:
			bools: ?b
			numbers: #n
			strings: $s
			arrays (tables, but strictly array access): @a
			tables (strictly string access): %t
			functions: &f, &f -> ##$, &f -> ...
			arbitrary: *x
				warning should be emitted on arbitrary typing
				requires casting to perform any operations

			no two variables may have the same name in a scope, the later will override the former
			redeclaring a variable with the same name (regardless of type) in the same exact scope should produce a compiler error

			variables can be declared individually by assignment or in groups by local/group declaration
				$new_string = 'asdf'
				local #start, #end
				global %world_table

		string interpolation into double-quoted strings indicated by their specific type declaration:
			print "i have a string: $mystring"
			print "i have a number #mynum"
			print "i have a bool: ?is_ded"

			print "i have a value: @a[5], @a[i]"
			print "i have a value: %self.value"
			print "i have a value: %self[key]"

			should there be string interpolation of arrays, tables, and functions?
		inherent solution of specific functions such as qw
			qw '
				asdf
				qwerty
				zxcv
			'
			would transpile directly to
			['asdf','qwerty', 'zxcv']
		named and anonymous functions with typed arguments can have default arg names
			default names:
				bools: b
				numbers: n
				strings: s
				arrays (tables, but strictly array access): a
				tables (strictly string access): t
				functions: f
					functions declared this way are assumed to be vararg all functions
				arbitrary: x
			examples:
				function fun $
					print "my string: $s"
				function fun ?$
					if b
						print "success: $s"
					else
						print "denied!"
				$ -> { print s }
				#& -> { return n * f() }
			if two arguments of the same type are required, numbers are appended to them starting with 1
				$$ -> { print "we have two variables: '$s1' and '$s2'" }
				?## -> {
					if b
						return n1
					else
						return n2
					}
		globals must be explicitly declared, otherwise the compiler errors out
			global $world
			print 'world name: ' + world.name
		function calls without parenthesis
			foo 5, 15, []
				becomes:
					foo(5, 15, {})

			foo 5, bar 'asdf'
				becomes:
					foo(5, bar('asdf'))


			parenthesis are still allowed where ambigious meaning needs to be discerned
				foo 5, bar(), 'asdf'
					becomes:
						foo(5, bar(), 'asdf')
		function declaration
			named functions:
				function foo
					print 'hello world!'
				
				function bar $x
					print x
			default function arguments:
				function foo #n=5, $s='world'
					// code
			vararg functions:
				function foo ...
					// code

				... is treated as a read-only array, translated to {...} everywhere
			anonymous functions:
				&f = { print 'hello world!' }
				&f = $x, $y -> { print "coords: $x, $y" }

			syntactic sugar for methods:
				method test
					print "hello world, i am %self"

				self is always a table, it assumed to be non-null

			when inside a table declaration, function and method declarations are sugared syntactically:
				[
					function asdf
						print 'in asdf!'
					function qwert
						print 'in qwert'
					method zxcv
						print 'i am %self in zxcv'
				]
					becomes
						{
							asdf = function () print('in asdf!') end,
							qwert = function () print('in qwert') end,
							zxvc = function (self) print ('i am ' .. self .. ' in zxcv') end,
						}

		syntactic sugar for calling functions with array/table constructors:
				foobar:
					a => 3
					b => 2 + asdf
					["prefix_$somevar"] => 5
			or
				barbaz:
					5
					asdf + '_suffix'
					15

			this allows neat little class definitions:
				class 'my_special_class':
					method _init
						self.val = 5
					method inc
						self.val++

			also allows nested definition execution:
				process:
					branch 'number':
						'lc'
						1
						'add'
					branch 'string':
						'lc'
						'1'
						'concat'

				becomes
					process({
						branch('number', {'lc', 1, 'add'}),
						branch('string', {'lc', '1', 'concat'})
					})


		forin to simplify array and table iteration with default arguements:
			arrays will always use ipairs while tables will always use pairs
			array keys and values are always represented as read-only variable #k, *v
				forin my_array
					print "my val: #v"
			table keys and values are always represented as read-only variables $k, *v
				forin my_table
					print "t[$k] => $v"
			when iterating on arbitrary values, will require a @ or % prefix to indicate which type to use
				forin @blueprint.sections
					// stuff


		array and table values are always interpreted as * values
		array keys are always interpreted as #
		table keys are always interpreted as $


		if statements:
			if v == 5
				print 'v is 5'
			elseif v < 5
				print 'v is less than 5'
			else
				print 'v is greater than 5'
			
		while statements:
			while t
				print "i have a table!"
			
		for statements:
			for #i = 1, 5
				print "iteration #i"
			for #i = 0, 100, 10
				print "iteration #i"


		traditional c-style comments:
			// asdf
				becomes
					-- asdf
			/* asdf */
				becomes
					--[[ asdf ]]

		next, last, and redo commands in while, for, and forin loops:
			while true
				last

			compiles to

			while true do
				goto last_12346
			end ::last_12346::


			while true
				next

			compiles to

			while true do
				goto next_12346
			::next_12346:: end


			while true
				redo

			compiles to

			while true do ::redo_12346::
				goto redo_12346
			end



