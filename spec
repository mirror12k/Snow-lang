


snow language spec draft v0.1
	compiles straight to lua code
	most syntax taken from lua
	features:
		.. operator merged with +
			(typed variables allow the compiler to discern the two)
		tables declared via []
			tables may only act as hash-tables or as array-tables, determined by how it is declared and how it is assigned to a variable
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

			should there be string interpolation of arrays, tables, and functions?
		inherent solution of specific functions such as qw
			qw '
				asdf
				qwerty
				zxcv
			'
			would transpile directly to
			['asdf','qwerty', 'zxcv']
		scopes declared via {}
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
				fun $ { print "my string: $s" }
				$ -> { print s }
				#& -> { return n * f() }
			if two arguments of the same type are required, numbers are appended to them starting with 1
				$$ -> { print "we have two variables: '$s1' and '$s2'" }
				?## -> { if b { return n1 } else { return n2 } }
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
				foo -> {
					print 'hello world!'
				}
				bar $x -> {
					print x
				}
			default function arguments
				foo #n=5, $s='world' -> {

				}
			vararg functions:
				example:
					foo ... -> {}
				... is treated as a read-only array, translated to {...} everywhere
			anonymous functions:
				{ print 'hello world!' }
				$x, $y -> { print "coords: $x, $y" }
		
		forin to simplify array and table iteration with default arguements:
			arrays will always use ipairs while tables will always use pairs
			array keys and values are always represented as read-only variable #k, *v
			table keys and values are always represented as read-only variables $k, *v
			when iterating on arbitrary values, will require a @ or % prefix to indicate which type to use
				forin @blueprint.sections {
					// stuff
				}


		array and table values are always interpreted as * values
		array keys are always interpreted as #
		table keys are always interpreted as $


		if statements:
			if v == 5 {
				print 'v is 5'
			}
		while statements:
			while t {

			}
		for statements:
			for #i = 1, 5 {

			}


		traditional c-style comments:
			// asdf
				becomes
					-- asdf
			/* asdf */
				becomes
					--[[ asdf ]]

