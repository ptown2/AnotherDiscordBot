local pretty = require('pretty-print')
local timer = require('timer')

-- Localise some stuff for caching
local string, table, coroutine = string, table, coroutine

local command = {}
command.triggers = {'lua', 'invoke', 'invokelua'}
command.description = 'Makes the bot invoke a lua script'
command.ownerOnly = true

local function code(str)
	return string.format('```\n%s```', str)
end

local function lua(str)
	return string.format('```lua\n%s```', str)
end

local function printLine(...)
	local ret = {}
	for i = 1, select('#', ...) do
		table.insert(ret, tostring(select(i, ...)))
	end
	return table.concat(ret, '\t')
end

local function prettyLine(...)
	local ret = {}
	for i = 1, select('#', ...) do
		table.insert(ret, pretty.dump(select(i, ...), nil, true))
	end
	return table.concat(ret, '\t')
end

local function handleError(msg, err)
	local reply = msg:reply(lua(err))
	return timer.setTimeout(5000, coroutine.wrap(function()
		msg:delete(); reply:delete()
	end))
end

local sandbox = setmetatable({
	require = require,
	discordia = discordia,
}, {__index = _G})

local function collect(success, ...)
	return success, table.pack(...)
end

function command:onMessageCreate(message, message_args)
	local arg, msg = message_args, message

	if not arg then return end
	if message.author.id ~= '107689627044827136' then return end

	arg = arg:gsub('```lua\n?', ''):gsub('```\n?', '')

	local lines = {}

	sandbox.message = msg
	sandbox.channel = msg.channel
	sandbox.guild = msg.guild
	sandbox.client = msg.client
	sandbox.print = function(...) table.insert(lines, printLine(...)) end
	sandbox.p = function(...) table.insert(lines, prettyLine(...)) end

	local fn, syntaxError = load(arg, 'PokeMastersBot', 't', sandbox)
	if not fn then return handleError(msg, syntaxError) end

	local success, res = collect(pcall(fn))
	if not success then return handleError(msg, res[1]) end

	if res.n > 0 then
		for i = 1, res.n do
			res[i] = tostring(res[i])
		end
		table.insert(lines, table.concat(res, '\t'))
	end

	local output = table.concat(lines, '\n')
	if #output > 1990 then
		return msg:reply {
			content = code('Content is too large. See attached file.'),
			file = {tostring(os.time()) .. '.txt', output}
		}
	elseif #output > 0 then
		return msg:reply(lua(output))
	end
end

bot.manager:addCommand(command)