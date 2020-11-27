local request = require('coro-http').request
local spawn = require('coro-spawn')
local split = require('coro-split')
local parse = require('url').parse
local timer = require('timer')
local json = require('json')

local ceil, floor, mod, min, max = math.ceil, math.floor, math.fmod, math.min, math.max

local function curtime()
	return os.time() + tonumber("0.".. string.match(tostring(os.clock()), "%d%.(%d+)"))
end

local function replace_char(pos, str, r)
    return ("%s%s%s"):format(str:sub(1,pos-1), r, str:sub(pos+1))
end

local function disp_time(time)
	local days = floor(time / 86400)
	local hours = floor(mod(time, 86400) / 3600)
	local minutes = floor(mod(time, 3600) / 60)
	local seconds = floor(mod(time, 60))

	if days > 0 then
		return ("%d day(s) %02d:%02d:%02d"):format(days, hours, minutes, seconds)
	elseif hours > 0 then
		return ("%02d:%02d:%02d"):format(hours, minutes, seconds)
	else
		return ("%02d:%02d"):format(minutes, seconds)
	end
end


local musicbot = {}
musicbot.trigger = "ytp"
--musicbot.triggers = { 'yt', 'youtube' }
musicbot.description = 'Music Bot Testing'
musicbot.ownerOnly = false
musicbot.onlyGuilds = true

musicbot.serverData = {}

musicbot.httpoptions = {
	host = 'https://www.googleapis.com',
	port = 443,
	path = '/youtube/v3/search?part=snippet&type=video&maxResults=1&key='.. APIKEY_GOOGLE ..'&q=',
	method = 'GET',
	headers = {
		{'User-Agent', 'ptown2 Discord Lua Bot'},
	},
	timeout = 10,
}


local progressbar, progressbarlen = "==============================", 30
function musicbot:makePlayerEmbed(data, guild, status)
	-- local ytthumb = data['thumbnails'][#data['thumbnails']]
	local embedtbl = {
		embed = {
			title = data.fulltitle,
			url = "https://www.youtube.com/watch?v=".. data.id,
			color = (self.text['status-color'][status] or 111111111),
			timestamp = discordia.Date():toISO('T', 'Z'),
			thumbnail = {url = data.thumbnail },
			-- thumbnail = {url = ytthumb.url, width = math.floor(ytthumb.width / 4), height = math.floor(ytthumb.height / 4)},
			-- image = {url = ytthumb.url, width = math.floor(ytthumb.width / 4), height = math.floor(ytthumb.height / 4)},
			footer = {
				text = self.text['embed-requested']:format(data.videoRequester.username, data.videoRequester.id),
				icon_url = data.videoRequester.avatarURL
			},
			author = {
				name = (self.text['status-text'][status] or 'Unknown Status'),
				icon_url = "https://pokemasters.ptown2.com/cdn/music_icon.png"
			},
			fields = {
				{ name = "Channel Name", value = data.uploader, inline = true },
				{ name = "View Count", value = math.commaformat(data['view_count']), inline = true },
				{ name = "Duration", value = disp_time(data.duration), inline = true },
				--{ name = "Requested by", value = '<@'.. data.videoRequester.id ..'>', inline = true }
			}
		}
	}

	local elapsedtm = floor(self.serverData[guild].playingTime.milliseconds / 1000)
	if status == 0 then
		local duration = 0
		local maxloop = #self.serverData[guild].musicQueue-1
		for loop = 1, maxloop do
			duration = duration + self.serverData[guild].musicQueue[loop].duration
		end

		table.insert(embedtbl.embed.fields, 4, { name = "Queue Position", value = "#".. (#self.serverData[guild].musicQueue or "Unknown Position"), inline = true })
		table.insert(embedtbl.embed.fields, 5, { name = "Estimated Wait Time", value = disp_time(max(0, duration - elapsedtm)), inline = true })
	elseif status == 3 then
		local calculation = max(math.ceil(elapsedtm / data.duration * progressbarlen), 1)
		table.insert(embedtbl.embed.fields, 4, { name = "Elapsed Time", value = self.text['elapsed-time']:format(disp_time(elapsedtm), replace_char(calculation, progressbar, "🔘"), disp_time(data.duration)), inline = false })
	end

	return embedtbl
end

function musicbot:getStreamData(url, msg, vchannel, guild, allowembed)
	local filecurtime = tostring(os.time())
	local child = spawn('youtube-dl', {
		--args = {url, '-f', 'worstaudio', '--geo-bypass', '--simulate', '--get-title', '--get-duration', '--get-id', '--get-url', '--get-thumbnail'},
		--args = {url, '-f', 'worstaudio', '--geo-bypass', '--skip-download', '--write-info-json', '-o', 'PokeMastersBot/storage/youtube/video'},
		args = {url, '-f', 'bestaudio', '--geo-bypass', '--skip-download', '--write-info-json', '-o', 'PokeMastersBot/storage/youtube/video'.. filecurtime},
		stdio = { nil, true, 2 }
	})
	child.waitExit()

	-- Merge chunk data for some reason...
	--[[
	local streamdata = ''
	for chunk in child.stdout.read do
		p(chunk)
	end
	]]
	--[[
	streamdata = json.decode(streamdata:gsub('\n', ''))
	streamdata['formats'] = nil
	]]
	local loadtest = io.open('/home/ptown2/PokeMastersBot/storage/youtube/video'.. filecurtime ..'.info.json', "r")
	if loadtest then
		streamdata = json.decode(loadtest:read("*a")) or {}
		streamdata.formats = nil
		streamdata.fragments = nil

		loadtest:close()
	end

	pcall(os.remove('/home/ptown2/PokeMastersBot/storage/youtube/video'.. filecurtime ..'.info.json'))
	--[[
	if not self.serverData[guild] then
		self.serverData[guild] = {
			messageGuild = {},
			musicQueue = {},
			playingTime = discordia.Stopwatch(true),
			voiceChannel = vchannel,
			loopMusicType = false,
		}
	end
	]]

	if streamdata and streamdata.id and (streamdata.url or streamdata.fragment_base_url) then
		if streamdata.title:find('rick roll') then
			return 'no'
		end

		local entrypos = #self.serverData[guild].musicQueue + 1
		self.serverData[guild].musicQueue[entrypos] = streamdata
		self.serverData[guild].musicQueue[entrypos].videoRequester = msg.member
		self.serverData[guild].musicQueue[entrypos].videoDuration = os.date('!%T', streamdata.duration)
		self.serverData[guild].musicQueue[entrypos].streamURL = streamdata.fragment_base_url and streamdata.fragment_base_url or streamdata.url

		if allowembed then
			pcall(msg:reply(self:makePlayerEmbed(self.serverData[guild].musicQueue[entrypos], guild, 0)))
		end

		self.serverData[guild].voiceChannel = vchannel,
		self:commenceAudioServ(msg, vchannel, guild)
	else
		msg:reply(self.text['invalid-streamdata']:format(url))
	end
end

function musicbot:grabPlaylistUrls(url, msg, vchannel, guild)
	local botmsg = msg:reply('Gathering playlist info...')
	local lastqueuecount = self.serverData[guild] and (#self.serverData[guild].musicQueue + 1) or 0

	local child = spawn('youtube-dl', {
		args = {url, '--flat-playlist', '--geo-bypass', '-J',},
		stdio = { nil, true, 2 }
	})
	child.waitExit()

	for chunks in child.stdout.read do
		local jsondata = json.decode(chunks)

		if jsondata then
			if not jsondata.entries then return pcall(botmsg:setContent(self.text['playlist-novideos'])) end
			if #jsondata.entries > 5 then if botmsg then return pcall(botmsg:setContent(self.text['playlist-videolimit'])) end end
			for _, entry in pairs(jsondata.entries) do
				if entry and entry.id and (entry.url or entry.fragment_base_url) then
					-- 'https://www.youtube.com/watch?v='..
					self:getStreamData(entry.id, msg, vchannel, guild)
				end
			end
		--else
		--	return pcall(botmsg:setContent(self.text['playlist-dataerror']))
		end
	end

	if botmsg then
		if lastqueuecount == #self.serverData[guild].musicQueue then
			pcall(botmsg:setContent(self.text['playlist-addfailure']))
		else
			pcall(botmsg:setContent(self.text['playlist-addsuccess']:format(#self.serverData[guild].musicQueue)))
		end
	end
end

function musicbot:commenceAudioServ(msg, channel, guildID)
	if not self.serverData[guildID].voiceConnection or not self.serverData[guildID].voiceConnection.channel then
		self.serverData[guildID].voiceConnection = channel:join()

		coroutine.wrap(function()
			-- this is to ensure that the coroutine isn't ran twice in a row...
			--local datasrvref = self.serverData[guildID]

			if not self.serverData[guildID].safetyCheck then
				self.serverData[guildID].safetyCheck = true

				while #self.serverData[guildID].musicQueue > 0 and (self.serverData[guildID].voiceConnection and self.serverData[guildID].voiceConnection.channel.id) do
					-- self.serverData[guildID].voiceConnection = channel:join()	-- Just incase, "re-join" on every new audio.
					if self.serverData[guildID].loopMusicType and (self.serverData[guildID].messageGuild and self.serverData[guildID].messageGuild.id) then
						pcall(self.serverData[guildID].messageGuild:update(self:makePlayerEmbed(self.serverData[guildID].musicQueue[1], guildID, 1)))
					else
						self.serverData[guildID].messageGuild = msg.channel:send(self:makePlayerEmbed(self.serverData[guildID].musicQueue[1], guildID, 1))
					end

					if not self.serverData[guildID].playingTime then
						self.serverData[guildID].playingTime = discordia.Stopwatch(true)
					end

					self.serverData[guildID].skipVotes = {}
					self.serverData[guildID].playingTime:reset()
					self.serverData[guildID].playingTime:start()
					local timeelapsed, reason = 0, 'none'
					if self.serverData[guildID].voiceConnection and self.serverData[guildID].voiceConnection.channel.id then
						timeelapsed, reason = self.serverData[guildID].voiceConnection:playFFmpeg(self.serverData[guildID].musicQueue[1].streamURL)
					end
					self.serverData[guildID].playingTime:stop()

					if (self.serverData[guildID].messageGuild and self.serverData[guildID].messageGuild.id) and not self.serverData[guildID].loopMusicType then
						local embedtbl = self:makePlayerEmbed(self.serverData[guildID].musicQueue[1], guildID, 2)
						embedtbl.content = self.text['stream-done']:format(reason, os.date('!%T', floor(timeelapsed / 1000)))
						pcall(self.serverData[guildID].messageGuild:update(embedtbl))
					end

					if self.serverData[guildID].voiceConnection and self.serverData[guildID].voiceConnection.channel.id then
						self.serverData[guildID].voiceConnection:stopStream()
					end

					if not self.serverData[guildID].loopMusicType then
						table.remove(self.serverData[guildID].musicQueue, 1)
					end
				end

				pcall(msg:reply(self.text['queue-empty']))

				if self.serverData[guildID].voiceConnection and self.serverData[guildID].voiceConnection.channel.id then
					self.serverData[guildID].voiceConnection:close()
				end

				self.serverData[guildID].musicQueue = {}
				self.serverData[guildID].safetyCheck = nil
				self.serverData[guildID].voiceConnection = nil
				self.serverData[guildID].voiceChannel = nil
				self.serverData[guildID].messageGuild = nil
			end
		end)()
	end
end

function musicbot:checkIfSameVC(botvc, vchannel)
	local datasrvref = botvc--self.serverData[guildID]

	if not datasrvref or not datasrvref.voiceChannel then return 'nil' end
	return datasrvref.voiceChannel == vchannel
end

function musicbot:onMessageCreate(msg, arg)
	local userID = msg.member.id
	local guildID = msg.guild.id
	local vchannel = msg.member.voiceChannel

	if not vchannel then return msg:reply(self.text['invalid-novc']) end

	if not self.serverData[guildID] then
		self.serverData[guildID] = {
			--messageGuild = {},
			musicQueue = {},
			playingTime = discordia.Stopwatch(true),
			loopMusicType = false,
			skipVotes = {},
		}
	end

	-- Split the command args
	local outcome, args = '', {}
	for str in arg:gmatch('%S+') do
		args[#args + 1] = str
	end

	timer.setTimeout(750, function()
		coroutine.wrap(function()
			if msg and (msg.embed or msg.embeds) then pcall(msg:hideEmbeds()) end
		end)()
	end)

	if not args[1] then return msg:reply(self.text['command-noargs']) end
	if not self:checkIfSameVC(msg.guild.me, vchannel) then return msg:reply(self.text['command-failvc']) end

	local datasrvref = self.serverData[guildID]
	if (args[1] == 'play' or args[1] == 'p') and args[2] then
		if not args[2]:find('[m%.]youtube%.com/watch%?v=') and not args[2]:find('youtu%.be/') then return pcall(msg:reply(self.text['command-invalidlink'])) end
		return self:getStreamData(args[2]:gsub('[<>]', ''), msg, vchannel, guildID, true)
	elseif (args[1] == 'playlist' or args[1] == 'plist') and args[2] then
		if not args[2]:find('[m%.]youtube%.com/playlist%?list=') then return pcall(msg:reply(self.text['command-invalidlink'])) end
		return self:grabPlaylistUrls(args[2]:gsub('[<>]', ''), msg, vchannel, guildID)
	elseif (args[1] == 'search' or args[1] == 'sr') and args[2] then
		pcall(msg:reply('Searching in youtube for video: `'.. table.concat(args, ' ', 2, #args) ..'`'))

		local searchterms = table.concat(args, '+', 2, #args)
		coroutine.wrap(function()
			local opt = self.httpoptions
			local res, body = assert(request(opt.method, opt.host .. opt.path .. searchterms, opt.headers, nil, opt.timeout))
			local ejson = json.parse(body)

			--p(ejson)
			if ejson and ejson.items and ejson.items[1] and ejson.items[1].id then
				self:getStreamData(ejson.items[1].id.videoId, msg, vchannel, guildID, true)
			elseif ejson and ejson.error then
				pcall(msg:reply(self.text['api-error']:format(body)))
			end
		end)()

		return
	elseif args[1] == 'loop' then
		datasrvref.loopMusicType = not datasrvref.loopMusicType
		return pcall(msg:reply('🎵 Looping current music has been set to `'.. tostring(datasrvref.loopMusicType) ..'`. PS: Skipping while loop is active will replay the same music.'))
	elseif (args[1] == 'queue' or args[1] == 'q') and (datasrvref.voiceConnection and datasrvref.voiceConnection.channel.id) then
		local queuelen, pagelimit, curduration = #datasrvref.musicQueue, 10, 0
		local maxpages = ceil(queuelen / pagelimit)
		local pagepos = min(maxpages, tonumber(args[2]) or 1) - 1

		if queuelen > 0 then
			local stringconcat = '**Current Queue List**:\n```'

			for pos, data in ipairs(datasrvref.musicQueue) do
				local txtpos = pos - 1

				if txtpos == 0 then
					stringconcat = stringconcat .. self.text['queue-entryformat']:format('Currently Playing:\n', data.title, disp_time(data.duration), data.videoRequester.username, data.videoRequester.id)..'---------------------------------\n'
				elseif (pagepos * pagelimit < txtpos and pagelimit * (pagepos+1) >= txtpos) then
					stringconcat = stringconcat .. self.text['queue-entryformat']:format(txtpos..'.', data.title, disp_time(data.duration), data.videoRequester.username, data.videoRequester.id)
				end

				curduration = curduration + data.duration
			end

			stringconcat = stringconcat .. '```' .. self.text['queue-footer']:format(queuelen-1, pagepos+1, maxpages, disp_time(curduration))
			pcall(msg:reply(stringconcat))
		else
			pcall(msg:reply(self.text['invalid-noqueue']))
		end

		return
	elseif (args[1] == 'remove' or args[1] == 'rm') and args[2] and (datasrvref.voiceConnection and datasrvref.voiceConnection.channel.id) then
		if not datasrvref.voiceConnection.channel.id then return pcall(msg:reply(self.text['command-invalidremove2'])) end
		local musicpos = tonumber(args[2])
		if musicpos then
			args[2] = max(args[2], 1) + 1
		else
			return pcall(msg:reply(self.text['command-posnan']))
		end

		if datasrvref.musicQueue[args[2]] and args[2] ~= 1 then
			pcall(msg:reply('❌ Removed '.. datasrvref.musicQueue[args[2]].title ..' from queue.'))
			table.remove(datasrvref.musicQueue, args[2])
		else
			pcall(msg:reply(self.text['command-invalidremove']))
		end

		return
	elseif (args[1] == 'pause' or args[1] == 'ps') and (datasrvref.voiceConnection and datasrvref.voiceConnection.channel.id) then
		pcall(datasrvref.messageGuild:setContent('Pausing audio...'))
		datasrvref.voiceConnection:pauseStream()
		datasrvref.playingTime:stop()

		return
	elseif (args[1] == 'resume' or args[1] == 'rs') and (datasrvref.voiceConnection and datasrvref.voiceConnection.channel.id) then
		pcall(datasrvref.messageGuild:setContent('Resuming audio...'))
		datasrvref.voiceConnection:resumeStream()
		datasrvref.playingTime:start()

		return
	elseif (args[1] == 'skip' or args[1] == 'sk') and (datasrvref.voiceConnection and datasrvref.voiceConnection.channel.id) then
		local milseclimit = 10000
		if datasrvref.playingTime.milliseconds > milseclimit then
			datasrvref.skipVotes[userID] = true

			local votecount, required = table.count(datasrvref.skipVotes), floor((#datasrvref.voiceConnection.channel.connectedMembers - 1) * 0.67)
			if votecount >= required then
				pcall(msg:reply(self.text['command-skpass']))
				datasrvref.voiceConnection:stopStream()
				datasrvref.playingTime:stop()
				datasrvref.playingTime:reset()
			else
				pcall(msg:reply(self.text['command-skvote']:format(userID, votecount, required)))
			end
		else
			pcall(msg:reply(self.text['invalid-cantskip']:format(milseclimit / 1000)))
		end

		return
	elseif (args[1] == 'current' or args[1] == 'playing' or args[1] == 'c' or args[1] == 'np') and (datasrvref.voiceConnection and datasrvref.voiceConnection.channel.id) then
		if datasrvref and datasrvref.musicQueue and datasrvref.musicQueue[1] then
			pcall(msg:reply(self:makePlayerEmbed(datasrvref.musicQueue[1], guildID, 3)))
		else
			pcall(msg:reply(self.text['invalid-notplaying']))
		end

		return
	end

	if self:checkIfSameVC(msg.guild.me, vchannel) == 'nil' then
		return msg:reply(self.text['command-failnovc'])
	end
end

bot.manager:addCommand(musicbot)


musicbot.text = {}
musicbot.text['stream-done'] = [[Stream End Reason: `%s`
Elapsed Time: `%s`
]]
musicbot.text['elapsed-time'] = '[%s] `%s` [%s]'
musicbot.text['invalid-streamdata'] = '🚫 Error happened, no stream data from that youtube id/url [`%s`] was valid.'
musicbot.text['invalid-novc'] = '🚫 You must be in a voice channel in the same guild you are chatting from for these commands to work.'
musicbot.text['invalid-notplaying'] = '❌ There is nothing currently playing on this guild.'
musicbot.text['invalid-noqueue'] = '❌ There is nothing currently in-queue on this guild.'
musicbot.text['invalid-cantskip'] = '❌ You cannot voteskip until %d second(s) has passed on this stream.'

musicbot.text['embed-requested'] = 'Requested by: %s [%s]'

musicbot.text['playlist-dataerror'] = '🚫 Invalid JSON data received by Youtube-dl.'
musicbot.text['playlist-novideos'] = '🚫 Playlist has no videos on list.'
musicbot.text['playlist-videolimit'] = '🚫 Too many videos in the playlist, denied.'
musicbot.text['playlist-addfailure'] = '🚫 An error occured with the playlist that could not add any entries.'
musicbot.text['playlist-addsuccess'] = '✅ Added playlist entries to music queue! It now has %s music audio(s) in queue.'

musicbot.text['queue-empty'] = '🎵 Ran out of audio queue, leaving voice channel. 🎵'
-- stringconcat = stringconcat .. '#'.. pos ..' - '.. data.title .. ' / Requested by: '.. data.videoRequester.username ..'\n'
musicbot.text['queue-footer'] = '**%s** songs in queue | Page **%s** of **%s** | **%s** total length.'
musicbot.text['queue-entryformat'] = [[%s %s | [%s]
]].. musicbot.text['embed-requested'] ..'\n'

musicbot.text['command-noargs'] = '🚫 You must specify a command argument. Use `help` for more info.'
musicbot.text['command-failvc'] = '🚫 You must be on the same voice channel I am binded to.'
musicbot.text['command-failnovc'] = '🚫 I can\'t run that command without being in a Voice Channel myself!'
musicbot.text['command-invalidlink'] = '🚫 Not a valid youtube link.'
musicbot.text['command-invalidremove'] = '🚫 You cannot remove the music that is currently playing or there is nothing in that queue position.'
musicbot.text['command-invalidremove2'] = '🚫 Denied removal. Nothing is playing.'
musicbot.text['command-posnan'] = '🚫 The position is not a number.'
musicbot.text['command-skvote'] = '👍 <@%s> has voted to skip! 🗳️ Current Votes: (%d/%d)'
musicbot.text['command-skpass'] = '👍 Voteskip has passed, skipped current audio!'

musicbot.text['api-error'] = [[⚠️⚠️⚠️ AN API ERROR OCCURED ⚠️⚠️⚠️
```
%s
```
]]

musicbot.text['status-text'] = {}
musicbot.text['status-text'][0] = 'Added to queue'
musicbot.text['status-text'][1] = 'Now playing...'
musicbot.text['status-text'][2] = 'Done playing...'
musicbot.text['status-text'][3] = 'Currently playing...'

musicbot.text['status-color'] = {}
musicbot.text['status-color'][0] = 11393254
musicbot.text['status-color'][1] = 11403055
musicbot.text['status-color'][2] = 15761536
musicbot.text['status-color'][3] = 11393254