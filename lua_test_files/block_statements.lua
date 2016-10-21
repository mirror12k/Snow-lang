

if true then
	print("hello world0!")
end

if true then
	print("hello world1!")
else
	print("errror1!")
end

if false then
	print("hello world2!")
else
	print("else 2!")
end

if false then
	print("hello world3!")
elseif true then
	print("elseif3!")
else
	print("else 3!")
end

if false then
	print("hello world4!")
elseif nil then
	print("elseif4!")
else
	print("else 4!")
end

a = 5

while a > 0 do
	print("my a: ", a)
	a = a - 1
end

while a < 5 do
	print("my a2: ", a)
	a = a + 1
end


repeat
	print('my repeat')
until true


for i = 0, 4 do
	print('my i:', i)
end

for i = 4, 0 do
	print('my i2:', i)
end

for i = 4, 0, -1 do
	print('my i3:', i)
end

for i = 0, 35, 10 do
	print('my i4:', i)
end

for i = 0, -35, -10 do
	print('my i5:', i)
end

