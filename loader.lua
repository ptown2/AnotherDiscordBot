--[[
	SinisterRectus's loader.lua from Luna
		Source: https://github.com/SinisterRectus/Luna/blob/master/loader.lua

	- Slightly altered for the sake of this bot's functionalities.
]]

local fs = require('fs') -- luvit built-in library
local pathjoin = require('pathjoin') -- luvit built-in library

local pathJoin = pathjoin.pathJoin
local readFileSync = fs.readFileSync
local scandirSync = fs.scandirSync

local loader = {modules = {}}

local env = setmetatable({
	require = require, -- inject luvit's custom require
	loader = loader, -- inject this module
}, {__index = _G})

function loader.unloadScript(name)
	if loader.modules[name] then
		loader.modules[name] = nil
		print('Script unloaded: ' .. name, '\n')
		return true
	else
		print('Unknown script: ' .. name, '\n')
		return false
	end
end

function loader.loadScript(name, dontOut)
	--if not dontOut then print('Loading script: ' .. name) end

	local success, err = pcall(function()
		local path = pathJoin('./', name) .. '.lua'
		local code = assert(readFileSync(path))
		local fn = assert(loadstring(code, '@' .. name, 't', env))
		loader.modules[name] = fn() or {}
	end)

	if success then
		if not dontOut then print('Script loaded: ' .. name, '\n') end
		return loader.modules[name]
	else
		if not dontOut then
			print('Script not loaded: ' .. name, '\n')
			print(err)
		end

		return nil
	end
end

function loader.loadScripts(scandir)
	for k, v in scandirSync(scandir) do
		if v == 'file' then
			local name = k:match('(.*)%.lua')
			if name and name:find('_') ~= 1 then
				loader.loadScript(scandir .. name)
			end
		end
	end
end

function loader.reloadScripts()
	loader.loadScript('PokeMastersBot/api-keys')
	loader.loadScript('PokeMastersBot/int-colors')

	loader.loadScripts('PokeMastersBot/classes/')
	loader.loadScripts('PokeMastersBot/modules/')
	loader.loadScripts('PokeMastersBot/commands/')

	loader.loadScript('PokeMastersBot/reload-ready')
	-- bot.manager:callEmitters('ready')

	print('all modules reloaded')
end


_G.process.stdin:on('data', function(data)
	local cmd, name = data:match('(%S+)%s+(%S+)')
	if not cmd then return end

	if cmd == 'reload' then
		if name == 'all' then
			return loader.reloadScripts()
		end

		return loader.loadScript(name)
	elseif cmd == 'unload' then
		return loader.unloadScript(name)
	end
end)

return loader