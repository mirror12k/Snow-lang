

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


local a,b = false, true

if a then
	print('hello world')
elseif b then
	print("what")
-- else
-- 	print('goodbye world')
end
