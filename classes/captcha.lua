-- Copyright startx <startx@plentyfact.org>
-- Modifications copyright mrDoctorWho <mrdoctorwho@gmail.com>
-- Published under the MIT license

--local ffi  = require "ffi"
--local gd = ffi.load('gd')
--local gd = require('/usr/lib/x86_64-linux-gnu/libgd.so')

local gd = require('/home/ptown2/PokeMastersBot/modules/gd')
local mt = { __index = {} }

function mt.new()
	local cap = {}
	local f = setmetatable({ cap = cap }, mt)
	return f
end

local function urandom()
	local seed = 1
	local devurandom = io.open("/dev/urandom", "r")
	local urandom = devurandom:read(32)
	devurandom:close()

	for i=1,string.len(urandom) do
		local s = string.byte(urandom,i)
		seed = seed + s
	end
	return seed
end

local function random_char(length)
	local set, char, uid
	local set = [[1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]]
	local captcha_t = {}

	math.randomseed(urandom())
	
	for c=1,length do
		 local i = math.random(1, string.len(set))
		 captcha_t[c] = string.sub(set, i, i)
		 -- table.insert(captcha_t, string.sub(set,i,i))
	end

	return captcha_t
end

local function random_angle()
	math.randomseed(urandom())
	return math.random(-50, 50) 
end

local function scribblew(w,h)
	math.randomseed(urandom())
	local x1 = math.random(2, w - 2)
	local x2 = math.random(2, w - 2)
	return x1, x2
end

local function scribbleh(w,h)
	math.randomseed(urandom())
	local x1 = math.random(2, h - 2)
	local x2 = math.random(2, h - 2)
	return x1, x2
end

function mt.__index:string(s)
	self.cap.string = s
end

function mt.__index:scribble(n)
	self.cap.scribble = n or 20
end

function mt.__index:length(l)
	self.cap.length = l
end


function mt.__index:bgcolor(r,g,b)
	self.cap.bgcolor = { r = r , g = g , b = b}
end

function mt.__index:fgcolor(r,g,b)
	self.cap.fgcolor = { r = r , g = g , b = b}
end

function mt.__index:bgimage(imagelocation)
	self.cap.fgcolor = imagelocation
end

function mt.__index:line(line)
	self.cap.line = line
end

function mt.__index:font(font)
	self.cap.font = font 
end

function mt.__index:generate(height)
	--local self.captcha = {}
	local captcha_t = {}

	if not self.cap.string then
		 if not self.cap.length then
			self.cap.length = 6
		 end
		 captcha_t = random_char(self.cap.length)
		 self:string(table.concat(captcha_t))
	else
		 for i=1, #self.cap.string do
		 	captcha_t[i] = string.sub(self.cap.string, i, i)
			-- table.insert(captcha_t, string.sub(self.cap.string, i, i))
		 end
	end

	local text_width = #captcha_t * 40 + 20
	self.im = gd.createTrueColor(text_width, height or 60)
	local black = self.im:colorAllocate(0, 0, 0)
	local white = self.im:colorAllocate(255, 255, 255)
	local bgcolor
	if not self.cap.bgcolor then
		 bgcolor = white
	else
		 bgcolor = self.im:colorAllocate(self.cap.bgcolor.r , self.cap.bgcolor.g, self.cap.bgcolor.b )
	end

	local fgcolor
	if not self.cap.fgcolor then
		fgcolor = black
	else
		fgcolor = self.im:colorAllocate(self.cap.fgcolor.r , self.cap.fgcolor.g, self.cap.fgcolor.b )
	end

	self.im:filledRectangle(0, 0, text_width, height or 60, bgcolor)
	
	local offset_left = 10

	for i=1, #captcha_t do
		local angle = random_angle()
		local llx, lly, lrx, lry, urx, ury, ulx, uly = self.im:stringFT(fgcolor, self.cap.font, 40, math.rad(angle), offset_left, 35, captcha_t[i])
		self.im:polygon({ {llx, lly}, {lrx, lry}, {urx, ury}, {ulx, uly} }, bgcolor)
		offset_left = offset_left + 40
	end

	if self.cap.line then
		fgcolor = self.im:colorAllocate(math.random(45, 215), math.random(45, 215), math.random(45, 215))

		self.im:line(10, 10, ( text_width ) - 10  , 40, fgcolor)
		self.im:line(11, 11, ( text_width ) - 11  , 41, fgcolor)
		self.im:line(12, 12, ( text_width ) - 12  , 42, fgcolor)
	end

	if self.cap.scribble then
		for i=1,self.cap.scribble do
			fgcolor = self.im:colorAllocate(math.random(45, 215), math.random(45, 215), math.random(45, 215))

			local x1,x2 = scribblew( text_width , height or 60 )
			local y1,y2 = scribbleh( text_width , height or 60 )

			self.im:line(x1, y1, x2, y2, fgcolor)
		end
	end
end


-- Perhaps it's not the best solution
-- Writes the generated image to a jpeg file
function mt.__index:jpeg(outfile, quality)
	self.im:jpeg(outfile, quality)
end

-- Writes the generated image to a png file
function mt.__index:png(outfile)
	self.im:png(outfile)
end

-- Allows to get the image data in PNG format
function mt.__index:pngStr()
	return self.im:pngStr()
end

-- Allows to get the image data in JPEG format
function mt.__index:jpegStr(quality)
	return self.im:jpegStr(quality)
end

-- Allows to get the image text
function mt.__index:getStr()
	return self.cap.string
end

-- Writes the image to a file
function mt.__index:write(outfile, quality)
	if self.cap.string == nil then
		self:generate()
	end

	self:jpeg(outfile, quality)
	-- Compatibility
	return self:getStr()
end

return mt