
-- for i, v in ipairs({'a','b','c'}) do
-- 	print('test1', i, v)
-- end

-- a = 3


local a = 5

;(function ()
	print(a)
end)()

;(function ()
	a = 4
	error("debug")
end)()

print(a)




-- function test ()
-- 	return function ()
-- 		print("closure_closure'd a: ", a)
-- 		a = a + 1
-- 	end
-- end

-- function test2 ()
-- 	return function ()
-- 		return function ()
-- 			print("super closure_closure'd a: ", a)
-- 			a = a + 1
-- 		end
-- 	end
-- end

-- test()()
-- print(a)
-- test2()()()
-- print(a)


