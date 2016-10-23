
-- for i, v in ipairs({'a','b','c'}) do
-- 	print('test1', i, v)
-- end


local thread, is_main = coroutine.running()
print(type(thread), is_main, coroutine.status(coroutine.running()))

local co = coroutine.create(function () 
	print("hello world! i am a coroutine")
	local thread, is_main = coroutine.running()
	print(type(thread), is_main, coroutine.status(coroutine.running()))
end)

print(type(co), coroutine.status(co))

print("resuming coroutine...")
coroutine.resume(co)
print(type(co), coroutine.status(co))
print("back in main")


coroutine.resume(coroutine.create(function () print("dead soon!"); (nil)(); print("never happens!") end))

