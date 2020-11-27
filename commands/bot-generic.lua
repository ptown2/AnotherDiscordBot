local request = require('coro-http').request

-- Shutdown bot
local command = {}
command.trigger = 'shutdown'
command.description = 'Bot shutdown'
command.ownerOnly = true

function command:onMessageCreate(msg)
	msg:reply('Shutting down!')

	bot.client:stop()
	process:exit(1)
end

bot.manager:addCommand(command)


-- Reboot bot
local command = {}
command.triggers = {'restart', 'reboot'}
command.description = 'Reboots all bot\'s features'
command.deleteMsg = true
command.ownerOnly = true

function command:onReady()
	--p('triggered ready')
	if bot.rebootMsg and bot.rebootMsg.id and bot.rebootMsg.content then
		bot.rebootMsg:setContent('Rebooted! Time Taken: '.. tostring(discordia.Date() - bot.rebootMsg:getDate()):gsub('%S+', {['Time:'] = '', ['milliseconds'] = 'ms'}))
	end
end

function command:onMessageCreate(msg)
	bot.rebootMsg = msg:reply('Rebooting bot...')
	botloader.reloadScripts()
end

bot.manager:addCommand(command)


local command = {}
command.trigger = 'snatchav'
command.description = 'grimsley method of snatching avatars'
command.deleteMsg = false
command.hideOnCommandList = true
command.ownerOnly = true

command.options = {
	host = 'https://ptown2.com', port = 443,
	path = '/stealav.php?apikey='.. APIKEY_AVSETTER ..'&imageurl=', method = 'GET',
	headers = {
		{'User-Agent', 'ptown2 Discord Lua Bot'},
	},
	timeout = 10,
}

function command:onMessageCreate(msg, arg)
	local avatar = nil

	--if arg then avatar = arg end
	if msg.attachments and #msg.attachments == 1 then
		avatar = msg.attachments[1].url
	end

	if not avatar and msg.mentionedUsers and #msg.mentionedUsers == 1 then
		for user in msg.mentionedUsers:iter() do
			avatar = user.avatarURL
		end
	end

	if not avatar and arg and (arg:find('http') or arg:find('https') or arg:find('www')) then
		avatar = arg
	elseif not avatar then
		return n_err('Avatar must be a single mentioned user, a valid URL with http/https appended, or an attachment.')
	end

	if avatar then
		coroutine.wrap(function ()
			local opt = self.options
			local res, body = assert(request(opt.method, opt.host .. opt.path .. avatar, opt.headers, nil, opt.timeout))

			if res.code == 200 and body then
				bot.client:setAvatar(body)
			end
		end)()
	end
end

bot.manager:addCommand(command)


local command = {}
command.trigger = 'setname'
command.description = 'Set a new username'
command.ownerOnly = true
command.deleteMsg = true

function command:onMessageCreate(msg, arg)
	if arg then
		bot.client:setUsername(arg)
	end
end

bot.manager:addCommand(command)


local command = {}
command.trigger = 'botsay'
command.description = 'Lets the bot say something'
command.ownerOnly = true
command.deleteMsg = true

function command:onMessageCreate(msg, arg)
	if arg then
		msg:reply(arg)
	end
end

bot.manager:addCommand(command)