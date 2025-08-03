# Luashi

![build status](https://github.com/selenil/luashi/workflows/Tests/badge.svg)

Tiny library for shell scripting with Lua (inspired by Python's sh module).

## Install

Via luarocks:

```bash
luarocks install --server=https://luarocks.org/dev luashi
```

From source: 

```bash
# clone this repo
git clone https://github.com/selenil/luashi.git 
cd luashi

# install
luarocks make 
# (optionally) install busted to run the tests
luarocks install busted
```

## Simple usage

Every command that can be called via `os.execute` can be used as a global function.
All the arguments passed into the function become command arguments.

``` lua
require('sh')

local wd = tostring(pwd()) -- calls `pwd` and returns its output as a string

local files = tostring(ls('/tmp')) -- calls `ls /tmp`
for f in string.gmatch(files, "[^\n]+") do
	print(f)
end
```

All enviroment variables that only consists of upper case letters are in scope.

```lua
require('sh')

print(HOME) -- prints your HOME directory
print(SHELL) -- prints the location of the shell you are using
```

## Command input and pipelines

If command argument is a table which has a `__input` field - it will be used as
a command input (stdin). Multiple arguments with input are allowed, they will
be concatenated.

Each command function returns a structure that contains the `__input`
field, so nested functions can be used to make a pipeline.

Note that the commands are not running in parallel (because Lua can only handle
one I/O loop at a time). So the inner-most command is executed, its output is
read, the the outer command is execute with the output redirected etc.

``` lua
require('sh')

local words = 'foo\nbar\nfoo\nbaz\n'
local u = uniq(sort({__input = words})) -- like $(echo ... | sort | uniq)
print(u) -- prints "bar", "baz", "foo"
```

If you need to run a command in the background without blocking the execution of the rest
of the program, use `sh.defer`. 

```lua
require('sh')

sh.defer("sleep 2")()

-- the execution of the program will continue without waiting 2 seconds
```

Pipelines can be also written as chained function calls. Lua allows to omit parens, so the syntax really resembles unix shell:

``` lua
-- $ ls /bin | grep $filter | wc -l

-- normal syntax
wc(grep(ls('/bin'), filter), '-l')
-- chained syntax
ls('/bin'):grep(filter):wc('-l')
-- chained syntax without parens
ls '/bin' : grep filter : wc '-l'
```

We can also iterate directly from the output of a command: 

```lua
for dir in ls("/bin") do
	print(dir)
end
```

## Partial commands and commands with tricky names

You can use `sh.command` to construct a command function, optionally
pre-setting the arguments:

``` lua
local sh = require('sh')

local truecmd = sh.command('true') -- because "true" is a Lua keyword
local chrome = sh.command('google-chrome') -- because '-' is an operator

local gittag = sh.command('git', 'tag') -- gittag(...) is same as git('tag', ...)

gittag('-l') -- list all git tags
```

`sh` module expose some convenience for common prefixes. 

```lua
local sh = require('sh')
local ln = sh.sudo('ln')

-- now ln() will be executed as `sudo ln`
ln("some-file", "some-symlink")
```

`sh` module itself can be used as a function to read environment variables or to construct commands functions as well.

## Exit status and signal values

Each command function returns a table with `__exitcode` and `__signal` fields.
Those hold the exit status and signal value as numbers. Zero exit status means
the command was executed successfully.

Since `f:close()` returns exitcode and signal in Lua 5.2 or newer - this will
not work in Lua 5.1 and current LuaJIT.

## Command arguments as a table

Key-value arguments can be also specified as argument table pairs:

```lua
require('sh')

-- $ somecommand --format=long --interactive -u=0
somecommand({format="long", interactive=true, u=0})
```
It becomes handy if you need to toggle or modify certain command line
argumnents without manually changing the argumnts list.

## Environment inheritance

Note that commands that changes the environment, like `export` or `cd` will not do an actual 
change in the rest of the program. For example: 

```lua
require('sh')

print(pwd()) -- some_dir
cd('other_dir')
print(pwd()) -- some_dir

export("MY_VAR", "my_value")
print(MY_VAR) -- nil
```

This is because each command runs in a separated process and thus the environment of each one
is not inherited by the other processes. 

The `sh` module exposes two functions, `sh.cd` and `sh.export` that actually change the environment for the rest of the program by using POSIX APIs. 

```lua
local sh = require('sh')

print(pwd()) -- some_dir
sh.cd('other_dir')
print(pwd()) -- other_dir

sh.export("MY_VAR", "my_value")
print(MY_VAR) -- my_value
```

## Colored output

For colored printing in the terminal, the `sh` provides some colors defined with `tput`. 

```lua
local sh = require('sh')
print(sh.GREEN .. "some message" .. sh.RESET)

-- same as the above
sh.pprint("some message", sh.GREEN)

sh.pprint("some message", sh.MAGENTA)
```

There's also some quick functions for printing in one specific color.

```lua
local sh = require('sh')

sh.success("It works!") -- prints the message in green
sh.warn("File not found") -- prints the message in yellow
sh.err("Something failed") -- prints the message in red
```

## Credits 

This project is a fork of http://github.com/zserge/luash, thanks to the original author for their work.

## License

Code is distributed under the MIT license.
