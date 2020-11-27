local request = require('coro-http').request
local json = require('json')

local youtube = {}
youtube.options = {
	host = 'https://www.googleapis.com',
	port = 443,
	path = '/youtube/v3/search?part=snippet&type=video&maxResults=1&key='.. APIKEY_GOOGLE ..'&q=',
	method = 'GET',
	headers = {
		{'User-Agent', 'ptown2 Discord Lua Bot'},
	},
	timeout = 10,
}

youtube.triggers = { 'yt2', 'youtube2' }
youtube.description = 'Searches via youtube in the deep dark fantasy web'

local searchtags = '+'
function youtube:onMessageCreate(msg, args)
	coroutine.wrap(function ()
		local opt = self.options
		local res, body = assert(request(opt.method, opt.host .. opt.path .. string.gsub(args, ' ', searchtags), opt.headers, nil, opt.timeout))
		local ejson = json.parse(body)

		p(ejson)
		if ejson and ejson.items then
			local search = ejson.items[1]

			if search then
				msg:reply({
					embed = {
						title = (search.snippet.title or 'No title available.'),
						description = (search.snippet.description or 'No description available.'),
						url = 'https://www.youtube.com/watch?v='.. search.id.videoId,
						image = {
							url = search.snippet.thumbnails.high.url,
							width = search.snippet.thumbnails.high.width,
							height = search.snippet.thumbnails.high.height,
						},
						color = COLOR_RED,
						footer = {
							text = 'Video published at '.. search.snippet.publishedAt
						},
					}
				})
			end
		elseif ejson and ejson.reason then
			n_err(ejson.reason)
		else
			n_err('Unable to parse youtube json data. Try again later.')
		end
	end)()
end

bot.manager:addCommand(youtube)