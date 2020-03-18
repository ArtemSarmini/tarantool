net = require('net.box')

--
-- gh-2666: check that netbox.call is not repeated on schema
-- change.
--
box.schema.user.grant('guest', 'write', 'space', '_space')
box.schema.user.grant('guest', 'write', 'space', '_schema')
box.schema.user.grant('guest', 'create', 'universe')
count = 0
function create_space(name) count = count + 1 box.schema.create_space(name) return true end
box.schema.func.create('create_space')
box.schema.user.grant('guest', 'execute', 'function', 'create_space')
c = net.connect(box.cfg.listen)
c:call('create_space', {'test1'})
count
c:call('create_space', {'test2'})
count
c:call('create_space', {'test3'})
count
box.space.test1:drop()
box.space.test2:drop()
box.space.test3:drop()
box.schema.user.revoke('guest', 'write', 'space', '_space')
box.schema.user.revoke('guest', 'write', 'space', '_schema')
box.schema.user.revoke('guest', 'create', 'universe')
c:close()
box.schema.func.drop('create_space')
