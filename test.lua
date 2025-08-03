local sh = require('sh')

describe("sh module", function()
    it("should call shell commands as regular functions", function()
        assert.is_not_nil(whoami())
        assert.is_not_nil(ls("/tmp"))
        assert.is_not_nil(echo("some message"))
    end)

    it("should access environment variables as regular variables", function()
        assert.is_not_nil(HOME)
        assert.is_not_nil(SHELL)
    end)

    it("command outputs should contain exit code", function()
        assert.True(ls("/tmp").__exitcode == 0)
    end)

    it("should group commands, passing the output of one as the input to the other", function()
        local result = wc(ls('/tmp'), '-l')
        assert.is_not_nil(result)
    end)

    it("should chain commands with :", function()
        local result = ls('/tmp'):wc("-l")
        assert.is_not_nil(result)
    end)

    it("should chain multiple commands", function()
        local result = wc(ls('/tmp'), ls('/tmp'), '-l')
        assert.is_not_nil(result)
    end)

    it("should extract command's output with sh.unwrap", function()
        local result = echo("output")
        assert.is_not_nil(result)

        local extracted = sh.unwrap(result)
        print(extracted)
        assert.are.equal(extracted, "output")
    end)

    it("should iterate over the output of a command", function()
        local count = 0
        for dir in ls("/tmp") do
            count = count + 1
        end
        assert.True(count > 0)
    end)

    it("should allow creating dynamic commands with multiple arguments", function()
        local e = sh.command('echo')
        local result = sh.unwrap(e('this', 'is', 'some', 'output'))
        assert.are.equal(result, "this is some output")
    end)

    it("should allow creating commands with predefined arguments", function()
        local greet = sh.command('echo', 'hello')
        local result = sh.unwrap(greet('world'))
        assert.are.equal(result, "hello world")
    end)

    it("should export environment variables", function()
        sh.export("MY_VAR", "my_value")
        assert.are.equal(MY_VAR, "my_value")
    end)

    it("should not leak environment variables outside the process", function()
        export("MY_OTHER_VAR", "my_value")
        assert.is_nil(MY_OTHER_VAR)
    end)

    it("should change directory using sh.cd", function()
        sh.cd("/tmp")
        local dir = sh.unwrap(pwd())
        assert.are.equal(dir, "/tmp")
    end)

    it("should run a callback in a specific directory using sh.run_in", function()
        local changed = false
        local original_dir = sh.unwrap(pwd())
        sh.run_in("/tmp", function() changed = true end)
        local dir_after_run = sh.unwrap(pwd())

        assert.True(changed)
        assert.are.equal(dir_after_run, original_dir)
    end)

    it("sh() should return the value of an environment variable", function()
        local home = sh("HOME")
        assert.are.equal(home, HOME)
    end)

    it("sh() should execute a shell command when given a command", function()
        local result = sh('type')('ls')
        assert.is_not_nil(result)
    end)
end)
