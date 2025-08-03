local sh = require('sh')

-- any shell command can be called as a function
print('User:', whoami())
print('Current directory:', pwd())

-- all environment variables that consists only of uppercase letters are in scope
print("Home directory: " .. HOME)
print("PATH: " .. PATH)

-- commands can be grouped into the pipeline as nested functions
print('Files in /bin:', wc(ls('/bin'), '-l'))
print('Files in /usr/bin:', wc(ls('/usr/bin'), '-l'))
print('files in both /usr/bin and /bin:', wc(ls('/usr/bin'), ls('/bin'), '-l'))

-- commands can be chained as in unix shell pipeline
print(ls('/bin'):wc("-l"))
-- Lua allows to omit parens
ls '/bin' : wc '-l' : print()

-- intermediate output in the pipeline can be stored into variables
local sedecho = sed(echo('hello', 'world'), 's/world/Lua/g')
print('output:', sedecho)
print('exit code:', sedecho.__exitcode)
local res = tr(sedecho, '[[:lower:]]', '[[:upper:]]')
print('output+tr:', res)

-- we can call sh.unwrap to extract the output of a command
local is_zsh_available = sh.unwrap(command("-v", "zsh")) ~= ""

-- we can directly iterate from the output of a command
for dir in ls(HOME) do
    print(dir)
end

-- command functions can be created dynamically. Optionally, some arguments
-- can be prepended (like partially applied functions)
local e = sh.command('echo')
local greet = sh.command('echo', 'hello')
print(e('this', 'is', 'some', 'output'))
print(greet('world'))
print(greet('foo'))

-- sh.defer() will run a command in the background, without blocking the script execution
-- and returns the PID of the new started process
local pid = sh.defer("sleep 2")()
print("I will be printed before the sleep ends")

-- sh module provides some convenience functions for common command prefixes
local ln = sh.sudo("ln") -- now whenever we call ln() it will be executed as "sudo ln ..."
ln("some-file", "some-symlink")

local luat = sh.tlua("lua") -- this will be executed as "time lua ..."
tlua("some-lua-file.lua")

-- calling export() will not make the variable avaliable for the rest of the script
-- because the current process won't inherit the environment
export("MY_VAR", "my_value")
print("MY_VAR") -- nil

-- use sh.export() instead
sh.export("MY_VAR", "my_value")
print(MY_VAR) -- my_value

-- calling cd() will not change the current working directory for the rest of the script
-- because the current process won't inherit the environment
print(pwd()) -- my_dir1
cd("my_dir2")
print(pwd()) -- my_dir1 

-- use sh.cd() instead
print(pwd()) -- my_dir1
sh.cd("my_dir2")
print(pwd()) -- my_dir2

-- we can pass an optional callback to run after the change
sh.cd("my_dir2", function() print("we are in my_dir2") end)

-- sh.run_in() runs a callback in a directory and then changes back to the original directory
print(pwd()) -- my_dir1
sh.run_in("my_dir2", function() print("we are in my_dir2")) end)
print(pwd()) -- my_dir1

-- sh module defines color constants created using tput for printing in the terminal
print(sh.GREEN .. "It works!" .. sh.RESET) -- prints the messages in green

-- shortcut for the above
sh.pprint("It works!", sh.GREEN)
sh.pprint("With any color", sh.MAGENTA)

sh.success("It works!")    -- prints the message in green
sh.warn("File not found")  -- prints the message in yellow
sh.err("Something failed") -- prints the message in red

-- the functions before always appends sh.RESET 
-- so the output remains colorless after the message is printed
print("without color")

-- sh module itself can be called as a function
-- if we pass a string that is only uppercase letters, then it will read the corresponding
-- environment variable, otherwise it will behave as an alias for sh.command()
print(sh("HOME"))
print(sh('type')('ls'))
sh 'type' 'ls' : print()

