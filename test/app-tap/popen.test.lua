#!/usr/bin/env tarantool

local popen = require('popen')
local tap = require('tap')

local test = tap.test('popen')
test:plan(2)

--
-- Trivial echo output.
--
local function test_trivial_echo_output(test)
    test:plan(6)

    local script = 'echo -n 1 2 3 4 5'
    local exp_script_output = '1 2 3 4 5'

    -- Start echo, wait it to finish, read the output and close
    -- the handler.
    local ph = popen.posix(script, 'r')
    local state, exit_code = ph:wait()
    test:is(state, popen.c.state.EXITED, 'verify exit status')
    test:is(exit_code, 0, 'verify exit code')
    local script_output = ph:read()
    test:is(script_output, exp_script_output, 'verify script output')
    local res, err = ph:close()
    test:is_deeply({res, err}, {true, nil}, 'close() successful')

    -- Verify that :close() is idempotent.
    local res, err = ph:close()
    test:is_deeply({res, err}, {true, nil}, 'close() is idempotent')

    -- Sending a signal using a closed handle gives an error.
    local exp_err = 'popen: attempt to operate on a closed handle'
    local res, err = ph:signal(popen.signal.SIGTERM)
    test:is_deeply({res, err}, {nil, exp_err},
                   'signal() on closed handle gives an error')
end

--
-- Test info and force killing of a child process.
--
local function test_kill_child_process(test)
    test:plan(10)

    -- Run and kill a process.
    local script = 'while true; do sleep 10; done'
    local ph = popen.posix(script, 'r')
    local res, err = ph:kill()
    test:is_deeply({res, err}, {true, nil}, 'kill() successful')

    local SIGNALED = popen.c.state.SIGNALED
    local SIGKILL = popen.signal.SIGKILL

    -- Wait for the process termination, verify wait() return
    -- values.
    local state, exit_code = ph:wait()
    test:is_deeply({state, exit_code}, {SIGNALED, SIGKILL},
                   'wait() return values')

    -- Verify state() return values for a terminated process.
    local state, exit_code = ph:state()
    test:is_deeply({state, exit_code}, {SIGNALED, SIGKILL},
                   'state() return values')

    -- Verify info for a terminated process.
    local info = ph:info()
    test:is(info.pid, -1, 'info.pid is -1')

    -- XXX: A shell script should be in quotes and quote escaped.
    -- Or kinda 'SHELL command' to don't confuse anybody.
    test:is(info.command, 'sh -c ' .. script, 'verify info.script')

    -- XXX: make flags readable (normalized opts), them it will be
    -- easier to test them
    -- test:is(info.flags, <...>, 'verify info.flags')

    -- XXX: look inconsistent: here 'signaled' string, SIGNALED
    -- constant above
    test:is(info.state, 'signaled', 'verify info.state')
    test:is(info.exit_code, SIGKILL, 'veridy info.exit_code')

    -- STDIN is NOT requested to be available for writing, so our
    -- end is set to -1 (childs end is closed).
    test:ok(info.stdin == -1, 'verify that stdin is closed')

    -- STDOUT requested to be available for reading, so the file
    -- descriptor should be available on our end.
    test:ok(info.stdout >= 0, 'verify stdout is available')

    -- STDERR is opened too, when STDOUT is requested for reading,
    -- to provide ability to use '2>&1' statement.
    test:ok(info.stderr >= 0, 'verify stderr is available')

    assert(ph:close())
end

test:test('trivial_echo_output', test_trivial_echo_output)
test:test('kill_child_process', test_kill_child_process)

os.exit(test:check() and 0 or 1)
