local Dispatcher = {}


function Dispatcher.new(max_items)
  max_items = tonumber(max_items)
  assert(max_items, 'Expected number for max items')
  local dispatcher = {
    next = 0,
    n = 0,
    max = max_items,
    cycle = 0,
  }
  return setmetatable(dispatcher, Dispatcher)
end


function Dispatcher.assign(d, obj)
  assert(d.n + 1 <= d.max, 'Unable to allocate space in dispatcher')
  d.n = d.n + 1

  local id
  repeat
    id = d.next
    d.next = (id + 1) % d.max
  until d[id] == nil
  if id == 0 then d.cycle = d.cycle + 1 end
  d[id] = {obj, d.cycle}

  return id, d.cycle
end


function Dispatcher.check(d, id, key)
  assert(d[id], 'No item at id ' .. id)
  assert(d[id][2] == key, 'Invalid key for item at id ' .. id)
end


function Dispatcher.remove(d, id, key)
  Dispatcher.check(d, id, key)
  if d[id] == nil then return end
  d.n = d.n - 1

  local res = d[id]
  d[id] = nil
  return res[1]
end


function Dispatcher.get(d, id, key)
  Dispatcher.check(d, id, key)
  return table.unpack(d[id])
end


function Dispatcher:__tostring()
  return string.format('Dispatcher(n: %d, max: %d)', self.n, self.max)
end


return Dispatcher
