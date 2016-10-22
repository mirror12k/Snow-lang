

-- ::asdf::

-- break
-- break
-- goto asdf

-- while false do
-- 	break;
-- end



-- if nil then
-- 	break
-- elseif ... then
-- 	break
-- else
-- 	goto F
-- end





-- for i = 1,5 do
-- 	break
-- end
-- for i = 1,5,2 do
-- 	break
-- end



-- for k,v in 1.5, true do
-- 	break
-- end


-- repeat
-- 	goto asdf
-- 	break
-- until nil

-- ::asdf::



-- function foo (a,b,c)
-- 	break
-- end
-- function obj.bar.baz (...)
-- 	break
-- end
-- function obj:asdf (v, ...)
-- 	break
-- end




-- local x,y = 5, true, ...

-- local function foo (a,b)
-- 	break
-- end



-- local v = function () local a = 5 return true end



-- local a = 5 + ~true - nil * ...
-- local b = -5 * 2 + 1

-- local a = print()
-- local a = obj:foo(5)
-- local a = obj.foo'asdf'


-- io.print('hey')
-- a,b = 5, true
-- fun = function ()
-- 	print()
-- end

-- a,b = (5 + 4)
-- bar = (function()
-- 	break
-- end)()


-- a = {}
-- b = {
-- 	3,
-- 	4;
-- 	5
-- }
-- c = {
-- 	asdf = 'asdf',
-- 	qwer = 'qwer',
-- }
-- d = {
-- 	[5 + 4] = asdf + qwer,
-- 	val = 15,
-- 	5
-- }


-- print{5, 4, 3}



-- return nil


-- local a,b,c,d,e,f = 5, 1
-- return a,b,c


-- local f = function () print('inside f!') end


-- print(5, 4)
-- f()


-- print((function () return 'hello!' end)())




-- goto my_stuff

-- ::my_stuff::
-- if false then
-- 	print('hey')
-- end

-- asdf(print('qwer'))



-- print (5, 4, 3, nil, true, 'asdf')

-- print(print())

-- ;(print)('hello world!')


-- do
-- 	local a,b = 5, 'asdf'
-- 	print(b, a)
-- 	local a,b = 5
-- 	print(a,b)
-- end
-- print(a,b)
-- return true


-- if true then
-- 	print('hello world!')
-- end

-- if nil then
-- 	print('hello world!')
-- end

-- while false do
-- 	print('hello world')
-- end


-- if true then
-- 	print("branch 1")
-- else
-- 	print('branch 2')
-- end

-- if nil then
-- 	print("branch 3")
-- else
-- 	print('branch 4')
-- end

-- local a = 5

-- repeat
-- 	print('hello world')
-- until false


-- local b,c

-- a, b = 5, 4, 3

-- print(a,b)

-- print(tonumber(nil), tonumber(false), tonumber(true), tonumber(''), tonumber('5'), tonumber({}))
-- print(nil or 5, false or 5, true or 5, '' or 5, '5' or 5, {} or 5)

-- print(5+nil)
-- print(5+true)
-- print(5+false)
-- print(5+'')
-- print(5+'5')
-- print(5+'a')
-- print(5+{})
-- print(5+function () end)

-- print (5 - 3)
-- print (5 * 3)
-- print (5 / 3)
-- print (5 % 3)
-- print (5 // 3)



-- print ('a' .. nil)
-- print ('a' .. false)
-- print ('a' .. true)
-- print ('a' .. 5)
-- print (4 .. 5)
-- print ('a' .. 'asdf')
-- print ('a' .. {})
-- print ('a' .. function () end)



-- a = 0
-- b = not a

-- print(a, b)

-- while b do
-- 	print(a, b)
-- 	a = a + 1
-- 	b = not a
-- end



-- while false do
-- 	print('hello world')
-- end

-- repeat
-- 	print('hello world')
-- until true


-- a, b = 5, 4, 3
-- print(b,a, c)


-- local a,b = false, true

-- if a then
-- 	print('hello world')
-- elseif b then
-- 	print("what")
-- else
-- 	print('goodbye world')
-- end

-- local c,a,d = 5, 4

-- print(a,b,c,d)
-- print(a+5, c - 4)


-- goto lol
-- ::start::

-- print('hello world')

-- goto ende
-- ::lol::

-- print('goodbye world')
-- goto start


-- ::ende::

-- while true do
-- 	print("in while")
-- 	while true do
-- 		print("helloworld!")
-- 		break
-- 		print("nope!")
-- 	end
-- 	print("leaving while")
-- 	break
-- 	print("nope")
-- end


-- print(5 <= 'a')


-- print(-nil)
-- print(-false)
-- print(-'5')

-- local a = 0
-- while a ~= -5 do
-- 	a = a - 1
-- 	print(a)
-- end


-- for i = 1, 5 do print(i) end
-- for i = 5, 1, -1 do print(i) end
-- for i = 10, 35, 10 do print(i) end
-- for i = 35, 10, -10 do print(i) end


-- for k, v in pairs({5, 4, a = 3, 2}) do
-- 	print(k, v)
-- end

-- o = {'asdf', [-1] = 'fdsa', ['1'] = 'qwer', [false] = 'zxvc', [{}] = 'zxvc', [function () end] = 'foobar'}

-- for k, v in pairs(o) do
-- 	print(type(k), k, v)
-- end


-- local t = {5,4,3, a='asdf', b='beta', [5+4] = 'arith', [false] = true}

-- print(t)
-- print(t.a, t.b, t.c)
-- t['a'], t['c'] = 15, true
-- print(t.a, t.b, t.c)

-- dump(t)




-- f = function (a,b)
-- 	print("hello world: ", a, b)
-- end

-- f(5, 4 , 3)

-- function f (...)
-- 	local a,b = ...
-- 	print(a,b)
-- end

-- f(5)
-- f(5,4)
-- f(5,4, 3)

-- function g (...)
-- 	local a,b = ..., 'lol'
-- 	print(a,b)
-- end

-- g(5)
-- g(5,4)
-- g(5,4, 3)

-- function h (a, ...)
-- 	g(...)
-- end

-- h(5)
-- h(5,4)
-- h(5,4, 3)


a = 3


local a = 5

;(function ()
	print(a)
end)()

;(function ()
	a = 4
end)()

print(a)


