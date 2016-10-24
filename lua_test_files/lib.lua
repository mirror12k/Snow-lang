



print(type(nil))
print(type(false))
print(type(5), type(5.4))
print(type(""), type("asdf"))
print(type({}), type({asdf="asdf"}))
print(type(function () end), type(type))







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

coroutine.resume(coroutine.create(function (a, b) print("resume args: ", a, b) end), 'asdf', 'qwerty')
coroutine.resume(coroutine.create(function (a, b) print("resume args2: ", a, b) end), 6)

local status, v1, v2, v3 = coroutine.resume(coroutine.create(function () return 'z', 'y' end))
print(status, v1, v2, v3)

local status = coroutine.resume(coroutine.create(function () return nil + 5 end))
print(status)



function stepper()
	coroutine.yield('step 1')
	coroutine.yield('step 2')
	coroutine.yield('step 3')
end

local co = coroutine.create(stepper)
print(coroutine.resume(co))
print(coroutine.status(co))
print(coroutine.resume(co))
print(coroutine.status(co))
print(coroutine.resume(co))
print(coroutine.status(co))
print(coroutine.resume(co))
print(coroutine.status(co))


coroutine.resume(coroutine.create(function (t) print('what'); print('parent:', coroutine.status(t)) end), coroutine.running())







