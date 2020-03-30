#!/usr/bin/env tarantool

local popen = require('popen')
local tap = require('tap')

local test = tap.test('popen')
test:plan(1)

--
-- Trivial echo output.
--
local function test_trivial_echo_output(test)
    test:plan(7)

    local script = 'echo -n 1 2 3 4 5'
    local exp_script_output = '1 2 3 4 5'

    -- Start echo, wait it to finish, read the output and close
    -- the handler.
    local ph = popen.posix(script, 'r')
    local err, state, exit_code = ph:wait()
    test:is(err, nil, 'wait() successful')
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

test:test('trivial_echo_output', test_trivial_echo_output)

os.exit(test:check() and 0 or 1)
