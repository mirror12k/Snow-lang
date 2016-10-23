


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



print("closures:")


a = 3


local a = 5

;(function ()
	print(a)
end)()

;(function ()
	a = 4
end)()

print(a)


function closure_counter()
	local i = 0
	return function ()
		i = i + 1
		return i
	end
end


fun = closure_counter()
print("counter 1:", fun())
print("counter 1:", fun())
print("counter 1:", fun())

fun = closure_counter()
print("counter 2:", fun())
print("counter 2:", fun())
print("counter 2:", fun())



function test ()
	return function ()
		print("closure_closure'd a: ", a)
		a = a + 1
	end
end

function test2 ()
	return function ()
		return function ()
			print("super closure_closure'd a: ", a)
			a = a + 1
		end
	end
end

test()()
print(a)
test2()()()
print(a)
