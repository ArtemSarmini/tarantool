#!/usr/bin/env tarantool

local popen = require('popen')
local ffi = require('ffi')
local errno = require('errno')
local fiber = require('fiber')
local clock = require('clock')
local tap = require('tap')

-- For process_is_alive().
ffi.cdef([[
    int
    kill(pid_t pid, int signo);
]])

-- {{{ Helpers

--
-- Verify whether a process is alive.
--
local function process_is_alive(pid)
    local rc = ffi.C.kill(pid, 0)
    return rc == 0 or errno() ~= errno.ESRCH
end

--
-- Verify whether a process is dead or not exist.
--
local function process_is_dead(pid)
    return not process_is_alive(pid)
end

--
-- Yield the current fiber until a condition becomes true or
-- timeout (60 seconds) exceeds.
--
-- Don't use test-run's function to allow to run the test w/o
-- test-run. It is often convenient during debugging.
--
local function wait_cond(func, ...)
    local timeout = 60
    local delay = 0.1

    local deadline = clock.monotonic() + timeout
    local res

    while true do
        res = {func(...)}
        -- Success or timeout.
        if res[1] or clock.monotonic() > deadline then break end
        fiber.sleep(delay)
    end

    return unpack(res, 1, table.maxn(res))
end

-- }}}

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
    local pid = ph:info().pid
    local state, exit_code = ph:wait()
    test:is(state, popen.c.state.EXITED, 'verify exit status')
    test:is(exit_code, 0, 'verify exit code')
    local script_output = ph:read()
    test:is(script_output, exp_script_output, 'verify script output')
    local res, err = ph:close()
    test:is_deeply({res, err}, {true, nil}, 'close() successful')

    -- Verify that the process is actually killed.
    local is_dead = wait_cond(process_is_dead, pid)
    test:ok(is_dead, 'the process is killed after close()')

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

--
-- Test that a loss handle does not leak (at least the
-- corresponding process is killed).
--
local function test_gc(test)
    test:plan(1)

    -- Run a process, verify that it exists.
    local script = 'while true; do sleep 10; done'
    local ph = popen.posix(script, 'r')
    local pid = ph:info().pid
    assert(process_is_alive(pid))

    -- Loss the handle.
    ph = nil -- luacheck: no unused
    collectgarbage()

    -- Verify that the process is actually killed.
    local is_dead = wait_cond(process_is_dead, pid)
    test:ok(is_dead, 'the process is killed when the handle is collected')
end

--
-- Simple read() / write() test.
--
local function test_read_write(test)
    test:plan(8)

    local payload = 'hello'

    -- The script copies data from stdin to stdout.
    local script = ('prompt=""; read -n %d prompt; echo -n "$prompt"')
        :format(payload:len())
    local ph = popen.posix(script, 'rw')

    -- Write to stdin, wait for termination, read from stdout.
    local res, err = ph:write(payload)
    test:is_deeply({res, err}, {true, nil}, 'write() succeeds')
    local state, exit_code = ph:wait()
    test:is(state, popen.c.state.EXITED, 'verify exit status')
    test:is(exit_code, 0, 'verify exit code')
    local res, err = ph:read()
    test:is_deeply({res, err}, {payload, nil}, 'read() from stdout succeeds')

    assert(ph:close())

    -- The script copies data from stdin to stderr.
    local script = ('prompt=""; read -n %d prompt; echo -n "$prompt" 1>&2')
        :format(payload:len())
    local ph = popen.posix(script, 'rw')

    -- Write to stdin, wait for termination, read from stderr.
    local res, err = ph:write(payload)
    test:is_deeply({res, err}, {true, nil}, 'write() succeeds')
    -- XXX: Move stderr flag to an options table.
    -- XXX: Should not read wait for a first byte?
    local state, exit_code = ph:wait()
    test:is(state, popen.c.state.EXITED, 'verify exit status')
    test:is(exit_code, 0, 'verify exit code')
    local res, err = ph:read(true)
    test:is_deeply({res, err}, {payload, nil}, 'read() from stderr succeeds')

    assert(ph:close())
end

local test = tap.test('popen')
test:plan(4)

-- XXX: add bad api usage cases
-- XXX: add popen.new() API test

test:test('trivial_echo_output', test_trivial_echo_output)
test:test('kill_child_process', test_kill_child_process)
test:test('gc', test_gc)
test:test('read_write', test_read_write)

os.exit(test:check() and 0 or 1)
