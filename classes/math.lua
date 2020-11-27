function math.commaformat(n) -- credit http://richard.warburton.it
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function math.clamp(number, min, max)
	return math.max(min, math.min(number, max))
end

function math.randomchoice(t) --Selects a random item from a table
	local keys = {}
	for key, value in pairs(t) do
		keys[#keys+1] = key --Store keys in another table
	end

	index = keys[math.random(1, #keys)]
	return index--t[index]
end