local pretty = require('pretty-print')

local function searchMember(guild, arg, msg)
	--local guild = msg.guild
	local members = guild.members
	local user = msg.mentionedUsers.first

	if not arg then return nil end
	local member = user and guild:getMember(user) or members:get(arg)
	if member then return member end

	if arg:find('#', 1, true) then
		local username, discriminator = arg:match('(.*)#(%d+)')
		member = members:find(function(m) return m.username == username and m.discriminator == discriminator end)
		if member then
			return member
		end
	end

	local distance = math.huge
	local lowered = arg:lower()

	for m in members:iter() do
		if m.nickname and m.nickname:lower():find(lowered, 1, true) then
			local d = m.nickname:levenshtein(arg)
			if d == 0 then
				return m
			elseif d < distance then
				member = m
				distance = d
			end
		end

		if m.username:lower():find(lowered, 1, true) then
			local d = m.username:levenshtein(arg)
			if d == 0 then
				return m
			elseif d < distance then
				member = m
				distance = d
			end
		end
	end

	if member then
		return member
	else
		return nil--, f('No member found for: `%s`', arg)
	end
end

local function search(guild, arg, msg)
	if not arg then return end
	arg = arg:lower():gsub('<[@][!](.-)>', '%1'):gsub('<[@](.-)>', '%1')

	local member = guild.members:get(arg)
	if member then return member end

	local distance = math.huge
	local levit = bot.loader.fuzzel.dld_e or string.levenshtein

	-- A more stricter fuzzy searching
	for m in guild.members:iter() do
		local nick, user = (m.nickname or m.name):lower(), m.user.username:lower()
		local d1, d2 = levit(arg, nick, 0.1, 0.1, 0.5, 1), levit(arg, user, 0.1, 0.1, 0.5, 1)
		local d = math.min(d1, d2)

		if d < distance then
			member = m
			distance = d
		end
	end

	return member
end

local command = {}
command.trigger = 'whois'
command.description = 'Makes the bot find a user. Searching plain-text is finnicky.'
--command.ownerOnly = true

function command:onMessageCreate(message, message_args)
	local arg, msg = message_args, message

	if not arg or #arg < 1 then return end
	arg = arg:lower()

	local member = searchMember(msg.guild, arg, msg)
	if not member then return end

	local name
	if member.nickname then
		name = string.format('%s (%s)', member.username, member.nickname)
	else
		name = member.username
	end

	return msg:reply {
		embed = {
			title = "Discord Whois",
			thumbnail = {url = member:getAvatarURL(), width = 256, height = 256},
			fields = {
				{name = 'Name', value = name, inline = true},
				{name = 'Discriminator', value = member.discriminator, inline = true},
				{name = 'ID', value = member.id, inline = true},
				{name = 'Status', value = member.status:gsub('^%l', string.upper), inline = true},
				{name = 'Joined Server', value = member.joinedAt:gsub('%..*', ''):gsub('T', ' '), inline = true},
				{name = 'Joined Discord', value = os.date('!%Y-%m-%d %H:%M:%S', member.createdAt), inline = true},
			},
			color = member:getColor().value,
		}
	}
end

bot.manager:addCommand(command)