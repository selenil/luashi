local posix = require "posix"

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

-- iterates over the output of a command following bash rules
-- TODO: Improve this implementation
local function iter(o)
	return string.gmatch(o, "%S+")
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
			__iter = iter(output),
			__exitcode = exit == 'exit' and status or 127,
			__signal = exit == 'signal' and status or 0,
		}
		local mt = {
			__index = function(self, k, ...)
				return _G[k] --, ...
			end,
			__call = function(self)
				-- allow to use it as an iterator
				return self.__iter()
			end,
			__tostring = function(self)
				-- return trimmed command output as a string
				return self.__input:match('^%s*(.-)%s*$')
			end
		}
		return setmetatable(t, mt)
	end
end

-- same as command(), but runs the cmd as a background process
-- without blocking the main thread and without capturing output
-- returns the pid of the started process
local function defer(cmd, ...)
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

		local pid = posix.fork()
		if pid == 0 then
			-- Redirect both stdout and stderr to /dev/null
			local null_dev = "/dev/null"
			os.execute(cmd .. " > " .. null_dev .. " 2>&1")
			os.exit(0) -- Ensure the child process exits
		elseif pid < 0 then
			-- Fork failed
			error("Failed to start background process")
		end

		return pid
	end
end

-- hook for undefined variables
-- returns the value of the corresponding enviroment variable
-- if the undefined variable only consists of capital letters,
-- otherwise executes it as a shell command
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

-- export command() and defer() functions, and configurable temporary "input" file
M.command = command
M.defer = defer
M.tmpfile = '/tmp/shluainput'

-- sets an environment variable
function M.export(var, name, overwrite)
	return posix.stdlib.setenv(var, name, overwrite)
end

-- changes the current working directory
-- optionally takes a callback as its last argument to run after the change
function M.cd(to, cb)
	status, errstr, errno = posix.unistd.chdir(to)
	if cb and status == 0 then cb() end

	return status, errstr, errno
end

-- runs a callback inside a given directory
-- and the returns to the previous directory
function M.run_in(to, cb)
	local pwd = command("pwd")()

	M.cd(to, cb)
	return M.cd(tostring(pwd))
end

-- returns a command function prefixed with "sudo"
function M.sudo(cmd) return command("sudo", cmd) end

-- returns a command function prefixed with "nice"
function M.nice(cmd) return command("nice", cmd) end

-- returns a command function prefixed with "time"
function M.time(cmd) return command("time", cmd) end

-- returns a command function prefixed with "timeout"
function M.timeout(cmd) return command("timeout", cmd) end

-- extracts the output of a command
M.unwrap = function(t) return tostring(t) end

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

-- pretty prints a string to the terminal
function M.pprint(msg, color)
	return print(color .. msg .. M.RESET)
end

-- pretty prints a message in green to the terminal
function M.success(msg) return M.pprint(msg, M.GREEN) end

-- pretty prints a message in yellow to the terminal
function M.warn(msg) return M.pprint(msg, M.YELLOW) end

-- pretty prints a message in red to the terminal
function M.err(msg) return M.pprint(msg, M.RED) end

-- Prompts the user for a yes/no question and returns
-- true if the selection was 'yes' or 'y', or false if it was 'no' or 'n'.
-- This function repeats the question until a valid answer is given.
function M.prompt(question)
	local tty_in = io.open("/dev/tty", "r")
	local tty_out = io.open("/dev/tty", "w")
	if not tty_in or not tty_out then
		error("Unable to access /dev/tty")
	end

	while true do
		tty_out:write(question .. " (yes/y or no/n): ")
		tty_out:flush()
		local response = tty_in:read("*l")
		if response then
			response = response:lower()
			if response == "yes" or response == "y" then
				tty_in:close()
				tty_out:close()
				return true
			elseif response == "no" or response == "n" then
				tty_in:close()
				tty_out:close()
				return false
			end
		end
		tty_out:write("Invalid response. Please type 'yes', 'y', 'no', or 'n'.\n")
	end
end

-- allow to call sh to read enviroment variables or run shell commands
setmetatable(M, {
	__call = function(_, var, ...)
		return handle_undefined_variable(var, ...)
	end
})

return M
