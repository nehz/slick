local Dispatcher = {}


function Dispatcher.new(max_items)
  max_items = tonumber(max_items)
  assert(max_items, 'Expected number for max items')
  return setmetatable({next = 0, n = 0, max = max_items}, Dispatcher)
end


function Dispatcher.assign(d, obj)
  assert(d.n + 1 <= d.max, 'Unable to allocate space in dispatcher')
  d.n = d.n + 1

  local id
  repeat
    id = d.next
    d.next = (id + 1) % d.max
  until d[id] == nil
  d[id] = obj

  return id
end


function Dispatcher.remove(d, id)
  if d[id] == nil then return end
  d.n = d.n - 1

  local res = d[id]
  d[id] = nil
  return res
end


return Dispatcher
