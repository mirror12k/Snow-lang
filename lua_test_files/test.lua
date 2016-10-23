
-- for i, v in ipairs({'a','b','c'}) do
-- 	print('test1', i, v)
-- end


local thread, is_main = coroutine.running()
print(type(thread), is_main)

local co = coroutine.create(function () 
	print("hello world! i am a coroutine")
end)

print(type(co))

print("resuming coroutine...")
coroutine.resume(co)
print("back in main")


