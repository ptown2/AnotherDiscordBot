-- PokeMastersBot; still in development.
discordia = require('discordia')
discordia.extensions()

botloader = require('./loader')

-- Setup the script env to use bot as part of _G.
bot = {}
bot.clock = discordia.Clock()
bot.clock:start()

bot.manager = botloader.loadScript('PokeMastersBot/bot-manager') --require('./botmanager')
bot.modeRun = bot.modeRun or 'DEFAULT'
bot.class = discordia.class
bot.client = discordia.Client({ cacheAllMembers = true, shardCount = 1, bitrate = 96000 })
bot.events = {
	'ready', 'guildAvailable', 'guildUpdate', 'userBan', 'userUnban',
	'memberJoin', 'memberLeave', 'memberUpdate',
	'roleCreate', 'roleUpdate', 'roleDelete', 'heartbeat',
	'reactionAdd', 'messageDelete'
}

-- Hook up other emitters.
for __, emit in ipairs(bot.events) do
	bot.manager.emitters[emit] = {}

	bot.client:on(emit, function(...)
		bot.manager:callEmitters(emit, ...)
	end)
end

-- Add in the custom emitter
bot.events[#bot.events + 1] = 'customMessageCreate'
bot.manager.emitters[bot.events[#bot.events]] = {}
bot.events[#bot.events + 1] = 'customBotMessageCreate'
bot.manager.emitters[bot.events[#bot.events]] = {}

-- Hook up the message create with bot.manager.
bot.client:on('messageCreate', function(message)
	bot.cacheMsg = message
	coroutine.wrap(function() bot.manager:onMessageCreate(message) end)()
end)

--[[bot.client:on('messageDelete', function(message)
	coroutine.wrap(function() bot.manager:onMessageDelete(message) end)()
end)]]


-- Overwrite the error function with our custom one.
n_err = function(...)
	if not bot.cacheMsg then return end

	--bot.client:getGuild('199688943443116032'):getChannel('747257115327987883')
	--bot.cacheMsg:reply({
	bot.client:getGuild('199688943443116032'):getChannel('747257115327987883'):send({
		embed = {
			title = 'An error occured!',
			fields = {
				{name = 'Error Reason:', value = unpack({...}), inline = true},
			},
			color = COLOR_LIGHTRED,
			timestamp = discordia.Date():toISO('T', 'Z'),
		}
	})
end

local olderr = _G.error
_G.error = function(...)
	p(...)
	n_err(...)
	olderr(unpack({...}))
end

-- Hook up error because why not.
bot.client:on('error', function(...)
	--n_err(...)
	bot.manager:callEmitter('Error', ...)
end)

-- Load the rest and run the client.
botloader.loadScript('PokeMastersBot/api-keys')
botloader.loadScript('PokeMastersBot/int-colors')
botloader.loadScripts('PokeMastersBot/classes/')
botloader.loadScripts('PokeMastersBot/modules/')
botloader.loadScripts('PokeMastersBot/commands/')

bot.client:run(APIKEY_DISCORD['GENERIC'])