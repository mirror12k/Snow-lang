
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


-- local t = {
-- 	asdf = 'allo',
-- 	qwer = "qwerty",
-- 	zxcv = 'zero',
-- }

-- print(t.asdf, t.zxcv, t.null, t.qwer, t.empty)

-- t.zxcv = 'zebra'
-- t.empty = false

-- print(t.asdf, t.zxcv, t.null, t.qwer, t.empty)
-- print(t['asdf'], t[5], t['qwer'], t.qwer, t.empty)


-- t = {
-- 	[true] = 5,
-- 	[{}] = 4,
-- 	[5] = 3,
-- }

-- t[4] = false;

-- print(t[true], t[false], t[4], t[{}])






-- for k, v in pairs({'a','b','c'}) do
-- 	print('pairs1', k, v)
-- end


-- for k, v in pairs({}) do
-- 	print('pairs2', k, v)
-- end

-- for k, v in pairs({a = 'asdf'}) do
-- 	print('pairs3', k, v)
-- end



-- for i = 0, 100000 do
	-- for k, v in pairs({ a = 'asdf', b = 'beta', [false] = 'nope!', [5] = '15' }) do
	-- 	-- print(k, v)
	-- end
-- end




break
::exp::
do
	while 5 do
		break
	end
	while 'asdf' do end
	repeat goto exp until true

	if true then
		break
	elseif false then
		goto what
	elseif 5 then
		goto stop
	else
	end

	::LOL::

	goto test
	goto LOL
	break;
end
