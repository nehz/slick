local Observable = {}


local function is_observable(o)
  return getmetatable(o) == Observable
end
Observable.is_observable = is_observable


local function is_table(t, mt)
  return type(t) == 'table' and getmetatable(t) == mt
end
Observable.is_table = is_table


local function is_indexable(o)
  -- Unwrap twice for slots (slot -> obs -> value(table))
  return is_table(Observable.unwrap(Observable.unwrap(o)))
end
Observable.is_indexable = is_indexable


local function observe_value(slot, v)
  assert(is_observable(slot) and slot['$slot'])

  -- Unregister current value observer
  local slot_v = rawget(slot, '$value')
  if slot_v ~= v and rawget(slot, '$value_observer') then
    assert(is_observable(slot_v))
    Observable.unwatch(slot_v, nil, slot['$value_observer'])
    rawset(slot, '$value_observer', nil)
  end

  -- Register new value observer
  if is_observable(v) and is_indexable(v) then
    rawset(slot, '$value_observer', function(v, idx, id)
      Observable.notify(slot, idx, v, id)
    end)
    Observable.watch(v, nil, slot['$value_observer'], slot)
  end
end


local function make_slot(o, t, idx, v)
  if is_table(v) then v = Observable.new(v) end
  local slot = Observable.new(v, {slot = true})
  rawset(slot, '$idx', idx)
  t[idx] = slot

  Observable.watch(slot, nil, function(v, idx, id)
    if idx == nil then
      Observable.notify(o, slot['$idx'], v, id)
    end
  end)

  observe_value(slot, v)
  return slot
end


function Observable.new(value, options)
  local o
  options = options or {}

  if not options.slot then
    assert(not is_observable(value), 'Value is [Observable]')
  end

  if is_table(value) then
    assert(getmetatable(value) == nil)

    -- Shape table into an observable
    o = value
    local t = {}
    for k, v in pairs(o) do
      make_slot(o, t, k, v)
      o[k] = nil
    end
    o['$value'] = t
  else
    o = {}
    o['$value'] = value
  end

  o['$observers'] = setmetatable({}, {__mode = 'v'})
  o['$observers_id'] = setmetatable({}, {__mode = 'k'})
  o['$slot'] = options.slot or false
  o['$merge'] = options.merge == nil and true or options.merge

  return setmetatable(o, Observable)
end


function Observable.wrap(v)
  if not is_observable(v) then
    return Observable.new(v)
  end
  return v
end


function Observable.unwrap(o, mt)
  if is_observable(o) then
    local v = rawget(o, '$value')
    if is_observable(v) then
      mt = rawget(v, '$mt') or mt
      assert(not v['$slot'], 'Should not be slot')
      assert(is_table(rawget(v, '$value'), mt), 'Unexpected value')
    elseif type(v) == 'table' then
      mt = rawget(o, '$mt') or mt
    end
    return v, mt
  end
  return o, mt
end


function Observable.unwrap_indexable(o)
  -- Unwrap twice for slots (slot -> obs -> value(table))
  local t, mt = Observable.unwrap(Observable.unwrap(o))
  assert(is_table(t, mt), '[table] expected, got ' .. tostring(t))
  return t
end


function Observable.watch(o, idx, f, scope, create_thread)
  assert(is_observable(o))

  if idx then o = Observable.index(o, idx, true) end
  scope = scope or rawget(getfenv(f), 'scope') or true

  -- TODO: possible to get function env from thread ?
  if create_thread then f = coroutine.create(f) end

  -- Use new table as a unique id
  local id = {}
  local ids = o['$observers_id']
  if not ids[scope] then ids[scope] = {} end

  o['$observers'][f] = scope
  ids[scope][f] = id

  return id, f
end


function Observable.unwatch(o, idx, f)
  assert(is_observable(o))

  if idx then
    o = Observable.index(o, idx)
    if not o then return end
  end

  local scope = o['$observers'][f]
  if scope then
    o['$observers'][f] = nil
    o['$observers_id'][scope][f] = nil
    return f
  end

  -- TODO: set clean up o[idx] if no watchers on itself or (grand)child(s)
end


function Observable.notify(o, idx, v, id)
  assert(is_observable(o))

  local observers = o['$observers']
  assert(observers)

  for callback, scope in pairs(observers) do
    local ids = o['$observers_id'][scope]
    assert(ids[callback])

    if type(scope) == 'table' and scope['$destroyed'] then
      observers[callback] = nil
      ids[callback] = nil
    else
      if type(callback) == 'thread' then
        if coroutine.status(callback) == 'dead' then
          observers[callback] = nil
        else
          if id == nil or ids[callback] ~= id then
            local ok, msg = coroutine.resume(callback, v, idx, id)
            if not ok then error(msg) end
          end
        end
      else
        if id == nil or ids[callback] ~=id then
          callback(v, idx, id)
        end
      end
    end
  end
end


function Observable.set(o, v, id)
  assert(is_observable(o))

  if getmetatable(v) == nil then
    if is_table(v) then v = Observable.new(v) end
    if is_indexable(v) then
      assert(is_observable(v))

      -- Merge keys into current table
      if v['$merge'] and o['$merge'] and is_indexable(o) then
        Observable.notify(o, nil, v, id)
        for k, slot in Observable.spairs(o) do
          Observable.set(slot, v[k], id)
        end
        for k, slot in Observable.spairs(v) do
          if not o[k] then
            Observable.set(Observable.index(o, k, true), v[k])
          end
        end
        return
      end
    end
  end

  Observable.notify(o, nil, v, id)
  if is_indexable(v) then
    for k, v in pairs(v) do
      Observable.notify(o, k, v, id)
    end
  end

  if o['$slot'] then observe_value(o, v) end
  rawset(o, '$value', v)
end


function Observable.set_index(o, idx, v, id)
  assert(is_observable(o))
  local t = Observable.unwrap_indexable(o)
  local slot = t[idx]
  if not slot then slot = make_slot(o, t, idx, nil) end
  Observable.set(slot, v, id)
end


function Observable.index(o, idx, create_nil)
  assert(is_observable(o))
  local t = Observable.unwrap_indexable(o)
  if t[idx] == nil then
    if not create_nil then return nil end
    make_slot(o, t, idx, nil)
  end
  return t[idx]
end


function Observable.set_metatable(o, mt)
  local t = Observable.unwrap_indexable(o)
  rawset(o, '$mt', mt)
  setmetatable(t, mt)
end


function Observable.set_slot(o, idx, slot)
  assert(is_observable(o))
  assert(is_observable(slot) and slot['$slot'], 'argument #2 is not a slot')
  local t = Observable.unwrap_indexable(o)
  t[idx] = slot
  return slot
end


function Observable.del_slot(o, idx)
  assert(is_observable(o))
  local t = Observable.unwrap_indexable(o)
  local slot = t[idx]
  t[idx] = nil
  return slot
end


function Observable.next(o, idx)
  assert(is_observable(o))
  local t = Observable.unwrap_indexable(o)
  local k = idx
  while true do
    k = next(t, k)
    if k == nil then return nil end

    local v = Observable.unwrap(t[k])
    if v ~= nil then return k, v end
  end
end


function Observable.inext(o, idx)
  assert(is_observable(o))
  local t = Observable.unwrap_indexable(o)
  local n = #t
  idx = idx + 1
  local v = Observable.unwrap(t[idx])
  if idx <= n and v ~= nil then return idx, v end
end


function Observable.snext(o, idx)
  assert(is_observable(o))
  local t = Observable.unwrap_indexable(o)
  local k = next(t, idx)
  return k, t[k]
end


function Observable.spairs(o)
  assert(is_observable(o))
  return Observable.snext, o, nil
end


function Observable:__newindex(idx, v)
  Observable.set_index(self, idx, v, debug.getinfo(2, 'f').func)
end


function Observable:__index(idx)
  local slot = Observable.index(self, idx)
  if slot == nil then return nil end
  return Observable.unwrap(slot)
end


function Observable:__len()
  --TODO: optimize this
  local n = 0
  for i in ipairs(self) do n = i end
  return n
end


function Observable:__pairs()
  return Observable.next, self, nil
end


function Observable:__ipairs()
  return Observable.inext, self, 0
end


function Observable:__tostring()
  if self['$slot'] then
    local value = Observable.unwrap(self)
    local fmt = type(value) == 'string' and "<'%s'>" or '<%s>'
    return string.format(fmt, tostring(value))
  end
  return string.format('Observable(%s)', tostring(Observable.unwrap(self)))
end


return Observable
