env = require('test_run')
test_run = env.new()
engine = test_run:get_cfg('engine')

uuid = require('uuid')
ffi = require('ffi')

-- check uuid indices
_ = box.schema.space.create('test', {engine=engine})
_ = box.space.test:create_index('pk', {parts={1,'uuid'}})

-- uuid indices support cdata uuids, 36- and 32- byte strings
-- and 16 byte binary strings
for i = 1,16 do\
    box.space.test:insert{uuid.new()}\
    box.space.test:insert{tostring(uuid.new())}\
    box.space.test:insert{tostring(uuid.new()):gsub('-', '')}\
end

a = box.space.test:select{}
err = nil
for i = 1, #a - 1 do\
    if tostring(a[i][1]):gsub('-', '') >= tostring(a[i+1][1]):gsub('-', '')\
            then err = {a[i][1], a[i+1][1]}\
    end\
end

err

box.space.test:drop()
