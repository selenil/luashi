local M = {}

-- converts key and it's argument to "-k" or "-k=v" or just ""
local function arg(k, a)
	if not a then return k end
	if type(a) == 'string' and #a > 0 then return k .. '=\'' .. a .. '\'' end
	if type(a) == 'number' then return k .. '=' .. tostring(a) end
	if type(a) == 'boolean' and a == true then return k end
	error('invalid argument type', type(a), a)
end

-- converts nested tables into a flat list of arguments and concatenated input
local function flatten(t)
	local result = { args = {}, input = '' }

	local function f(t)
		local keys = {}
		for k = 1, #t do
			keys[k] = true
			local v = t[k]
			if type(v) == 'table' then
				f(v)
			else
				table.insert(result.args, v)
			end
		end
		for k, v in pairs(t) do
			if k == '__input' then
				result.input = result.input .. v
			elseif not keys[k] and k:sub(1, 1) ~= '_' then
				local key = '-' .. k
				if #k > 1 then key = '-' .. key end
				table.insert(result.args, arg(key, v))
			end
		end
	end

	f(t)
	return result
end

-- returns a function that executes the command with given args and returns its
-- output, exit status etc
local function command(cmd, ...)
	local prearg = { ... }
	return function(...)
		local args = flatten({ ... })
		local s = cmd
		for _, v in ipairs(prearg) do
			s = s .. ' ' .. v
		end
		for k, v in pairs(args.args) do
			s = s .. ' ' .. v
		end

		if args.input then
			local f = io.open(M.tmpfile, 'w')
			f:write(args.input)
			f:close()
			s = s .. ' <' .. M.tmpfile
		end
		local p = io.popen(s, 'r')
		local output = p:read('*a')
		local _, exit, status = p:close()
		os.remove(M.tmpfile)

		local t = {
			__input = output,
			__exitcode = exit == 'exit' and status or 127,
			__signal = exit == 'signal' and status or 0,
		}
		local mt = {
			__index = function(self, k, ...)
				return _G[k] --, ...
			end,
			__tostring = function(self)
				-- return trimmed command output as a string
				return self.__input:match('^%s*(.-)%s*$')
			end
		}
		return setmetatable(t, mt)
	end
end

-- hook for undefined variables
-- if a variable only consists of capital letters,
-- we treat it as environment variable,
-- otherwise we treat it like a shell command
local function handle_undefined_variable(var, ...)
	if var == string.upper(var) then
		return os.getenv(var)
	end

	return command(var, ...)
end

-- get global metatable
local mt = getmetatable(_G)
if mt == nil then
	mt = {}
	setmetatable(_G, mt)
end

-- set hook for undefined variables
mt.__index = function(_, var)
	return handle_undefined_variable(var)
end

-- export command() function and configurable temporary "input" file
M.command = command
M.tmpfile = '/tmp/shluainput'

-- export some conveniences for common prefixes
M.sudo = function(cmd) return command("sudo", cmd) end
M.nice = function(cmd) return command("nice", cmd) end
M.time = function(cmd) return command("time", cmd) end
M.timeout = function(cmd) return command("timeout", cmd) end

-- export convenience function to extract the output of a command
M.unwrap = function(t) return t.__input end

-- export colors utilities
local tput = command("tput")
M.RESET = M.unwrap(tput("sgr0"))
M.RED = M.unwrap(tput("setaf", "1"))
M.GREEN = M.unwrap(tput("setaf", "2"))
M.BLACK = M.unwrap(tput("setaf", "0"))
M.GREEN = M.unwrap(tput("setaf", "2"))
M.BLUE = M.unwrap(tput("setaf", "4"))
M.CYAN = M.unwrap(tput("setaf", "6"))
M.WHITE = M.unwrap(tput("setaf", "7"))
M.YELLOW = M.unwrap(tput("setaf", "3"))
M.MAGENTA = M.unwrap(tput("setaf", "5"))

local echo = command("echo")
local quote = function(s) return "'" .. s .. "'" end

-- function to pretty print a string
function M.pprint(msg, color) return echo(quote(color .. msg .. M.RESET)):print() end

-- function to print a message in green
function M.success(msg) return echo(quote(M.GREEN .. msg .. M.RESET)):print() end

-- function to print a message in yellow
function M.warn(msg) return echo(quote(M.YELLOW .. msg .. M.RESET)):print() end

-- function to print a message in red
function M.err(msg) return echo(quote(M.RED .. msg .. M.RESET)):print() end

-- allow to call sh to read enviroment variables or run shell commands
setmetatable(M, {
	__call = function(_, var, ...)
		return handle_undefined_variable(var, ...)
	end
})

return M
