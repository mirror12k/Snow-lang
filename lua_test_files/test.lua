
-- bug where yl bytecode was loading more locals due to the stack being larger
-- fixed by truncating the stack before assigning
function fun(...)
	local a = ...
	local b
	print(a,b)
end

function foo(a)
	local b
	print(a,b)
end

-- so this would overflow into local b, which should be nil instead
fun(5,4)
foo(5,4)

