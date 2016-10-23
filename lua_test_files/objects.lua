



local obj = { val=15, }
local dupe = { val=17, }

function obj.fun(a)
	print("this is obj.fun with ", a)
end
function obj:sudo(a)
	print("this is obj:sudo with ", self.val, a)
end


obj.fun('astro')
obj:sudo('magic')
obj.sudo(dupe, 'dupe')

