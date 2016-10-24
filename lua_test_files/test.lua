
-- for i, v in ipairs({'a','b','c'}) do
-- 	print('test1', i, v)
-- end



-- print('a' or 'b')
-- print(nil or 'b')
-- print(false or 'b')
-- print(0 or 'b')



-- print('a' and 'b')
-- print(nil and 'b')
-- print(false and 'b')
-- print(0 and 'b')



-- dump({a = 5, b = 4})
-- dump({
-- 	[true] = 5,
-- 	[{}] = 4,
-- 	[5] = 3,
-- })

-- dump{10,20,30}


local t = {
	asdf = 'allo',
	qwer = "qwerty",
	zxcv = 'zero',
}

print(t.asdf, t.zxcv, t.null, t.qwer, t.empty)

t.zxcv = 'zebra'
t.empty = false

print(t.asdf, t.zxcv, t.null, t.qwer, t.empty)
print(t['asdf'], t[5], t['qwer'], t.qwer, t.empty)


t = {
	[true] = 5,
	[{}] = 4,
	[5] = 3,
}

t[4] = false;

print(t[true], t[false], t[4], t[{}])
