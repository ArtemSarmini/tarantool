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
    test:plan(2)

    local script = 'while true; do sleep 10; done'
    local ph = popen.posix(script, 'r')
    local res, err = ph:kill()
    test:is_deeply({res, err}, {true, nil}, 'kill() successful')

    local SIGNALED = popen.c.state.SIGNALED
    local SIGKILL = popen.signal.SIGKILL

    local state, exit_code = ph:wait()
    test:is_deeply({state, exit_code}, {SIGNALED, SIGKILL},
                   'wait() gave signal information')
    --[[
    ph:state()
    info = ph:info()
    info.command
    info.state
    info.flags
    info.exit_code
    ]]--
    assert(ph:close())
end

test:test('trivial_echo_output', test_trivial_echo_output)
test:test('kill_child_process', test_kill_child_process)

os.exit(test:check() and 0 or 1)
