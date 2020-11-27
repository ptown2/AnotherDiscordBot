-- Ping Command
local command = {}
command.trigger = 'ping'
command.description = 'Connection testing'

command.heartbeat = 'NO HEARTBEAT'
command.heartshard = 'none'

--[[
function command:canMessageCreate(msg, args)
	return self.heartbeat ~= 'NO HEARTBEAT'
end
]]

local function curtime()
	return os.time() + tonumber("0.".. string.match(tostring(os.clock()), "%d%.(%d+)"))
end

function command:preMessageCreate()
	self.exectime = discordia.Stopwatch()
	self.sendtime = curtime()
	--self.exectime:start()
end

function command:onMessageCreate(msg)
	self:preMessageCreate()
	local timedelay = tostring(discordia.Date() - msg:getDate()):gsub('%S+', {['Time:'] = '', ['milliseconds'] = 'ms'})--string.sub(math.abs(self.sendtime - msg.createdAt) * 1000, 1, 5).. 'ms'
	self.exectime:stop()
	local timeexec = (self.exectime.milliseconds*1000).. ' ms'
	msg:reply({
		embed = {
			title = 'Ponged a packet back to you!',
			fields = {
				{name = '🖥️ Execution Time', value = timeexec, inline = true},
				{name = '💬 Message Time', value = timedelay, inline = true},
				{name = '💓 Heartbeat', value = self.heartbeat, inline = true},
			},
			color = COLOR_OUTPUT,
			timestamp = discordia.Date():toISO('T', 'Z'),
		}
	})
end

function command:onHeartbeat(shard, latency)
	self.heartbeat = tostring(latency).. ' ms'
	self.heartshard = shard
end

bot.manager:addCommand(command)


-- About Command
local command = {}
command.trigger = 'botinfo'
command.description = 'Info on what the bot is running on'
command.versions = {}

local versions = {}
function command:onReady()
	versions = {}
	versions[#versions + 1] = _VERSION .. ' Copyright (C) 1994-2008 Lua.org, PUC-Rio'

	versions[#versions + 1] = ''
	versions[#versions + 1] = '~~ LUVIT APP ~~'

	local luvit = io.popen('luvit -v')
	for line in luvit:lines() do
		versions[#versions + 1] = line
	end
	luvit:close()

	--[[
	versions[#versions + 1] = ''
	versions[#versions + 1] = '~~ LUVI APP ~~'
	for line in io.popen('luvi --version'):lines() do
		versions[#versions + 1] = line
	end

	versions[#versions + 1] = ''
	versions[#versions + 1] = '~~ LIT APP ~~'
	for line in io.popen('lit -v'):lines() do
		versions[#versions + 1] = line
	end]]

	self.versions = table.concat(versions, '\n')
end

function command:onMessageCreate(msg)
	return msg:reply('I\'m running Discordia with Luvit!\n```'.. self.versions ..'```')
end

bot.manager:addCommand(command)


-- Command Lists Command
local command = {}
command.triggers = {'commands', 'help'}
command.description = 'List of commands the bot uses'
command.listcache = { {name = 'Uh oh...', value = 'NO COMMANDS LOADED', inline = false} }

function command:onReady()
	local av_dupes = {}
	self.listcache = {}

	for _, cmd in pairs(bot.manager.cmdCached) do
		--p( cmd )
		cmd = bot.manager.commands[cmd]

		if cmd and not av_dupes[cmd] and not cmd.hideOnCommandList then
			table.insert(self.listcache, {
				name = bot.manager.prefix .. table.concat(cmd.triggers or {cmd.trigger}, ', '.. bot.manager.prefix) .. (cmd.ownerOnly and ' [mngr]' or ''),
				value = cmd.description or 'No description',
				inline = false,
			})
			av_dupes[command.trigger] = true
		end
	end
end

function command:onMessageCreate(msg)
	return msg:reply('Please refer now to the new commands page:\nhttp://pokemasters.ptown2.com:8080/')--[[msg:reply({
		embed = {
			title = 'Gazerheadbot Commands',
			fields = self.listcache,
			color = COLOR_OUTPUT,
			footer = {
				text = 'List of bot commands. [mngr] = Bot creator only'
			},
		}
	})]]
end

bot.manager:addCommand(command)


-- Command Lists Command
local command = {}
command.trigger = 'serverinfo'
command.description = 'Generic server information'

function command:onMessageCreate(msg)
	if not msg.guild then return n_err('Invoking command that isn\'t part of a server.') end
	local guild = msg.guild

	local online = 0
	for member in guild.members:iter() do
		if member.status ~= 'offline' then
			online = online + 1
		end
	end

	local owner = guild.owner
	return msg:reply {
		embed = {
			thumbnail = {url = guild.iconURL, width = 256, height = 256},
			fields = {
				{name = 'Name', value = guild.name, inline = true},
				{name = 'ID', value = guild.id, inline = true},
				{name = 'Owner', value = string.format('%s#%s', owner.username, owner.discriminator), inline = true},
				{name = 'Created At', value = os.date('!%Y-%m-%d %H:%M:%S', guild.createdAt), inline = true},
				{name = 'Online Members', value = tostring(online), inline = true},
				{name = 'Total Members', value = tostring(guild.totalMemberCount), inline = true},
				{name = 'Text Channels', value = tostring(#guild.textChannels), inline = true},
				{name = 'Voice Channels', value = tostring(#guild.voiceChannels), inline = true},
				{name = 'Roles', value = tostring(#guild.roles), inline = true},
			},
			color = math.random(9999, 999999)
		}
	}
end

bot.manager:addCommand(command)


local command = {}
command.trigger = 'dscstatus'
command.description = 'Check discord\'s status page'
