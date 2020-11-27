local timer = require('timer')
local dsc = {}

dsc.prefix = '$'
dsc.cmdCached = {}
dsc.commands = {}
dsc.emitters = {}
dsc.guildroles = {
	['583120259708616715'] = '602992760076894256'
}
dsc.roleowners = {
	['602992760076894256'] = true
}
dsc.botowners = {
	['107689627044827136'] = true,
}

local function validEmitterFunc(meta, func, ...)
	if meta and meta[func] then
		return meta[func](meta, ...)
	end

	return nil
end

function dsc:setPrefix(prefix)
	if not prefix then return end

	if bot.cacheMsg then
		bot.cacheMsg:reply('New prefix set.')
	end

	self.prefix = prefix
end

local isadded = {}
function dsc:addCommand(cmdtbl)
	if not cmdtbl or (not cmdtbl.trigger and not cmdtbl.triggers) then return end

	-- Handle the triggers and add them.
	if cmdtbl.triggers then
		for __, trig in ipairs(cmdtbl.triggers) do
			self.commands[trig] = cmdtbl
			self.commands[trig].trigger = trig
		end
	end

	if cmdtbl.trigger then
		self.commands[cmdtbl.trigger] = cmdtbl
	end

	-- Handle the other events the "commands" have.
	for __, emit in ipairs(bot.events) do
		if cmdtbl['on'.. (emit:gsub('^%l', string.upper))] and self.emitters[emit] and not isadded[cmdtbl.trigger] then
			--p(self.emitters[emit], cmdtbl.trigger)
			table.insert(self.emitters[emit], cmdtbl.trigger)
			--self.emitters[emit][#self.emitters[emit] + 1] = cmdtbl.trigger
		end
	end

	-- Add it to the cache list in order.
	if not isadded[cmdtbl.trigger] then
		table.insert(self.cmdCached, cmdtbl.trigger)
		isadded[cmdtbl.trigger] = true
	end

	print('~ added command: ', cmdtbl.trigger)
	return cmdtbl
end

function dsc:callEmitter(emitter, metatable, ...)
	upperemit = (emitter:gsub('^%l', string.upper))

	-- With the on prefix or without.
	local emitfunc = metatable['on'.. upperemit] or metatable[emitter]
	if emitfunc and type(emitfunc) == 'function' then
		local values = {pcall(emitfunc, metatable, ...)}

		local status, err = values[1], values[2]
		if not status and err then n_err(err) return end

		table.remove(values, 1)
		return unpack(values)
	end

	if emitfunc == nil then
		return true
	end

	return false
end

function dsc:callEmitters(emitter, ...)
	if not self.emitters[emitter] then return end

	for __, meta in ipairs(self.emitters[emitter]) do
		upperemit = (emitter:gsub('^%l', string.upper))

		if self.commands[meta] then
			local emitfunc = self.commands[meta]['on'.. upperemit] or self.commands[meta][emitter]

			if emitfunc and type(emitfunc) == 'function' then
				--emitfunc(self.commands[meta], ...)
				local status, err = pcall(emitfunc, self.commands[meta], ...)
				--if not status and err then n_err(err) end
			end
		end
	end
end

-- TODO: Similar to Garry's Mod hook.
function dsc:addEmitter(emitter)
end

function dsc:getCommandArgs(content)
	local c_match = { __index = function (table, key) return key or '' end }
	c_match = setmetatable({ content:match('(%'.. self.prefix ..'+)(%S+) ?(.*)') }, c_match)

	return c_match
end

function dsc:isCommandValid(message, m_command, cmd_match, override)
	local content = message.content
	local __, m_count = tostring(cmd_match[3]):gsub('%S+', '')

	-- What if the prefix is not the same?
	if (self.prefix ~= cmd_match[1]) or (content:sub(1, #self.prefix) ~= self.prefix) then return nil end

	-- What if the command does not exist, or is owner only, or too many args?
	if not m_command and not override then return nil end
	if m_command.onlyGuilds and not message.guild then return false, 'This command only works in guilds.' end
	if m_command.ownerOnly and (not self.botowners[message.author.id] or not message.guild) and (message.guild and not message.member:hasRole(self.guildroles[message.guild.id])) then return false, 'Command is for guild admins/mods or bot owner/creator only.' end
	if m_command.maxArgs and (m_count > m_command.maxArgs) then return false, 'Too many command arguments. Max args for '.. (m_command.trigger or 'that command') ..' is '.. m_command.maxArgs ..' argvalues.' end

	-- p(m_command.trigger, dsc:callEmitter('canMessageCreateEvent', m_command, message, cmd_match[3]))
	-- p(dsc:callEmitter('canMessageCreateEvent', m_command, message, cmd_match[3]))
	return dsc:callEmitter('canMessageCreateEvent', m_command, message, cmd_match[3])
end

function dsc:onMessageCreate(message)
	--print(os.date('!%Y-%m-%d %H:%M:%S', message.createdAt).. ' | ['.. message.guild.name ..' - #'.. message.channel.name ..'] <'.. message.author.name.. '>: '.. message.content)
	self:callEmitters('customBotMessageCreate', message)

	if message.author.bot then return end

	local content = message.content
	cmd_match = self:getCommandArgs(content)

	-- Call the custom message create emitters.
	self:callEmitters('customMessageCreate', message)

	-- Find the command and try to handle it.
	local m_command = self.commands[cmd_match[2]]
	local hasValid, hasReason = self:isCommandValid(message, m_command, cmd_match)
	--p(hasValid, hasReason)
	if hasValid then
		-- Execute the chat commands.
		local status, err = pcall(m_command.onMessageCreate, m_command, message, cmd_match[3])
		if not status and err then n_err(err) end

		if m_command.deleteMsg then pcall(message:delete()) end
	elseif hasValid ~= nil then
		hasReason = hasReason or 'No error reason specified.'
		pcall(message:reply('❌ Failed to use command for the reason of: `'.. hasReason ..'`'))
	end
end

function dsc:onMessageDelete(message)
	if message.author.bot then return end

	self:callEmitters('messageDelete', message)
end

return dsc


	--true --(testval ~= nil) or (testval ~= false)
	--n_err('Invalid bot command.') return false end
	--if self.prefix ~= cmd_match[1] then return false end
	-- if not (dsc:callEmitter('canMessageCreateEvent', m_command, message, cmd_match[3]) == false) then return end
	-- local testval = validEmitterFunc(m_command, 'canMesssgeCreate', message, cmd_match[3])