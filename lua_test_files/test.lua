



function f (...)
	local a,b = ...
	print(a,b)
end

function g (...)
	local a,b = ..., 'lol'
	print(a,b)
end

function h (a, ...)
	g(...)
end

h(5)




function ret ()
	return 'asdf','qwer'
end

local a,b,c = ret()
print(a,b,c)
local a,b,c = ret(), true
print(a,b,c)
local a,b,c = false, ret()
print(a,b,c)



function ret ()
	return 'asdf','qwer'
end

local a,b,c = ret()
print(a,b,c)
local a,b,c = ret(), true
print(a,b,c)
local a,b,c = false, ret()
print(a,b,c)
