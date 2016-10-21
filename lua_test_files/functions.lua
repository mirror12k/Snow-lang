


local a,b = 4
print(a,b)

local c,d = 15,16,17
print(a,b,c,d)

b,d = true, nil
print(a,b,c,d)






function f (...)
	local a,b = ...
	print(a,b)
end

f(5)
f(5,4)
f(5,4,3)

function g (...)
	local a,b = ..., 'lol'
	print(a,b)
end

g(5)
g(5,4)
g(5,4,3)

function h (a, ...)
	g(...)
end

h(5)
h(5,4)
h(5,4,3)




function ret ()
	return 'asdf','qwer'
end

local a,b,c = ret()
print(a,b,c)
local a,b,c = ret(), true
print(a,b,c)
local a,b,c = false, ret()
print(a,b,c)


function spawn ()
	return function () return 'spa','wn' end
end

print(spawn()())

