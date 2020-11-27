local nextseed = 0
local function setnewseed()
	if nextseed < os.time() then
		nextseed = os.time() + 1
		math.randomseed(nextseed)
	end
end

local cmd = {}
cmd.trigger = 'russian'
cmd.description = 'Russian roulette'
cmd.deleteMsg = true
cmd.savedchambers = {}

function cmd:onMessageCreate(msg, arg)
	if not msg.guild then return n_err('Invoking command that isn\'t part of a server.') end
	local outcome, color = ":confounded::gun: ***CLICK!***  <@!".. msg.author.id ..">, you're lucky that it hasn't triggered. :four_leaf_clover:", COLOR_LIGHTGREEN

	-- Set a new random seed.
	setnewseed()

	-- Randomize and reduce the chambers
	local chams = self.savedchambers[msg.guild.id] or 6
	local num1, num2 = math.random(chams), math.random(chams)

	if not ( num1 == num2 ) then
		self.savedchambers[msg.guild.id] = chams - 1
	else
		outcome, color = ":skull_crossbones::gun: ***BANG!***  <@!".. msg.author.id ..">, you're dead kiddo. :coffin:", COLOR_RED
		self.savedchambers[msg.guild.id] = 6
	end

	msg:reply({
		embed = { description = outcome, color = color }
	})
end

bot.manager:addCommand(cmd)


local cmd = {}
cmd.triggers = {'die', 'dice'}
cmd.description = 'Rolls x dice(s) with y side(s)'
cmd.maxArgs = 2
cmd.deleteMsg = true

local function clamp(val, var1, var2)
	return math.max(math.min(tonumber(val), var2), var1)
end

function cmd:onMessageCreate(msg, arg)
	-- Grab args
	local dice, sides
	local args = {}
	for num in arg:gmatch('(%d+)') do
		args[#args + 1] = tonumber(num)
	end

	-- Clamp
	dice, sides = clamp(args[1] or 1, 1, 99999), clamp(args[2] or 6, 1, 99999)

	-- Set a new random seed.
	setnewseed()

	-- Show outcome
	local outcome = ':game_die: <@!'.. msg.author.id ..'>, has rolled a '.. dice ..'d'.. sides..' dice! It came out '.. math.random(dice, dice * sides)
	msg:reply({
	embed = {
		description = outcome, color = COLOR_OUTPUT
	}})
end

bot.manager:addCommand(cmd)


local cmd = {}
cmd.triggers = {'slots'}
cmd.description = 'slots machine'
-- cmd.deleteMsg = true

cmd.reels = { '', '' ,'' }
cmd.reeltypes = {
	{ icon = ':cherries:',		payoff = 2,	rarity = 5 },
	{ icon = ':strawberry:',	payoff = 5,	rarity = 5 },
	{ icon = ':peach:',		payoff = 7.5,	rarity = 5 },
	{ icon = ':lemon:',		payoff = 10,	rarity = 5 },
	{ icon = ':banana:',		payoff = 15,	rarity = 5 },
	{ icon = ':grapes:',		payoff = 20,	rarity = 5 },
	{ icon = ':eggplant:',		payoff = 50,	rarity = 5 },
	{ icon = ':rainbow:',		payoff = 100,	rarity = 5 },
}

function cmd:determineSlotWin()
	--for self.ree
	return self.reels[1] == self.reels[2] and self.reels[2] == self.reels[3]
end

function cmd:randomize()
	for id, reel in ipairs(self.reels) do
		-- if not math.random(1, 2) == 1 then return end

		-- local nextslot = self.reeltypes[math.random(1, #self.reeltypes)]
		-- local random = math.random(1, nextslot.Rarity)

		-- if random <= 2 then
		self.reels[id] = self.reeltypes[math.random(1, #self.reeltypes)].icon
		-- end
	end
end

function cmd:onMessageCreate(msg, arg)
	-- Set a new random seed.
	setnewseed()

	-- Split the command args
	local outcome, args = '', {}
	for str in arg:gmatch('%S+') do
		args[#args + 1] = str
	end

	self:randomize()

	local outcome = table.concat(self.reels, ' - ') .. ' :arrow_left:'

	if self:determineSlotWin() then
		outcome = outcome .. '\n\n' .. '**SLOTS WINNER!**'
	end

	-- Show outcome
	msg:reply({
		content = '<@!'.. msg.author.id ..'>, here\'s your slot results!',
		embed = {
			description = ':arrow_right: '.. outcome, color = COLOR_OUTPUT
		}
	})
end

bot.manager:addCommand(cmd)
