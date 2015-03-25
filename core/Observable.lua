local Observable = {}


local function is_observable(o)
  return getmetatable(o) == Observable
end
Observable.is_observable = is_observable


local function is_table(t)
  if type(t) == 'table' then
    if getmetatable(t) == Observable then return false end
    return true
  end
  return false
end
Observable.is_table = is_table


function Observable.new(value, is_chain)
  local o

  if is_table(value) then
    assert(getmetatable(value) == nil)

    -- Shape table into an observable
    local copy = {}
    for k, v in pairs(value) do
      if is_table(v) then v = Observable.new(v) end
      copy[k] = Observable.new(v)
      value[k] = nil
    end
    o = value
    rawset(o, '$value', copy)
  else
    o = {}
    rawset(o, '$value', value)
  end

  o['$observers'] = {}
  o['$chain'] = is_chain or false
  return setmetatable(o, Observable)
end


function Observable.chain(o1, o2, is_direct_chain)
  assert(is_observable(o1) and is_observable(o2), '[Observable] expected')
  assert(#o1['$observers'] == 0, '[Observer] migration not yet supported yet')

  o1['$chain'] = true
  if not is_direct_chain then o2 = Observable.resolve(o2) end
  rawset(o1, '$value', o2)
end


function Observable.resolve(o)
  assert(is_observable(o))
  if o['$chain'] then
    return Observable.resolve(rawget(o, '$value'))
  end
  return o
end


function Observable.wrap(v)
  if not is_observable(v) then
    return Observable.new(v)
  end
  return v
end


function Observable.unwrap(o, parent)
  if is_observable(o) then
    if o['$chain'] then
      return Observable.unwrap(rawget(o, '$value'), o)
    else
      return rawget(o, '$value'), o
    end
  end
  return o, parent
end


function Observable.watch(o, idx, f, scope, create_thread)
  if idx then o = Observable.index(o, idx, true) end
  scope = scope or rawget(getfenv(f), '$scope') or {}

  -- TODO: possible to get function env from thread ?
  if create_thread then f = coroutine.create(f) end

  o = Observable.resolve(o)
  o['$observers'][f] = scope
end


function Observable.unwatch(o, idx, f)
  if idx then
    o = Observable.index(o, idx)
    if not o then return end
  end

  o = Observable.resolve(o)
  o['$observers'][f] = nil

  -- TODO: set clean up o[idx] if no watchers on itself or (grand)child(s)
end


function Observable.notify(o, idx, v, id)
  local obs = o['$observers']
  local c = rawget(o, '$value')
  assert(obs)

  if is_observable(c) then
    Observable.notify(c, nil, v, id)
  end

  for callback, scope in pairs(obs) do
    if scope and rawget(scope, '$destroyed') then
      obs[callback] = nil
    else
      if type(callback) == 'thread' then
        if coroutine.status(callback) == 'dead' then
          obs[callback] = nil
        else
          local success, msg = coroutine.resume(callback, v, idx, id)
          if not success then error(msg) end
        end
      else
        callback(v, idx, id)
      end
    end
  end
end


function Observable.set(o, v, id)
  local r = Observable.resolve(o)
  rawset(r, '$value', v)
  Observable.notify(r, nil, v, id)
end


function Observable.set_index(o, idx, v, id)
  assert(is_observable(o))

  local t, p = Observable.unwrap(o)
  assert(type(t) == 'table', 'Cannot index: ' .. tostring(t))
  assert(not is_observable(t))

  local slot = rawget(t, idx)
  if not slot then
    t[idx] = Observable.new(v)
  else
    Observable.set(slot, v, id)
  end
  Observable.notify(p, idx, v, id)
end


function Observable.index(o, idx, create_nil)
  assert(is_observable(o))

  local t = Observable.unwrap(o)
  assert(type(t) == 'table', 'Cannot index: ' .. tostring(t))

  if is_observable(t) then
    return Observable.index(t, idx, create_nil)
  end

  if t[idx] == nil then
    if not create_nil then return nil end
    t[idx] = Observable.new(nil)
  end

  return t[idx]
end


function Observable.next(o, idx)
  assert(is_observable(o))

  local t = Observable.unwrap(o)
  assert(type(t) == 'table', '[table] expected, got ' .. tostring(t))
  assert(not is_observable(t))

  local k = next(t, idx)
  return k, o[k]
end


function Observable.inext(o, idx)
  assert(is_observable(o))

  local t = Observable.unwrap(o)
  assert(type(t) == 'table', '[table] expected, got ' .. tostring(t))
  assert(not is_observable(t))

  local n = rawget(t, '$n') or #t
  idx = idx + 1
  if idx <= n then return idx, o[idx] end
end


function Observable:__newindex(idx, v)
  assert(self['$chain'] == false)
  if is_table(v) then v = Observable.new(v) end
  Observable.set_index(self, idx, v)
end


function Observable:__index(idx)
  local slot = Observable.index(self, idx)
  if slot == nil then return nil end

  local v, p = Observable.unwrap(rawget(slot, '$value'))
  if type(v) == 'table' then return p end
  return v
end


function Observable:__len()
  local t = Observable.unwrap(self)
  assert(type(t) == 'table', '[table] expected, got ' .. tostring(t))
  return rawget(t, '$n') or #t
end


function Observable:__pairs()
  return Observable.next, self, nil
end


function Observable:__ipairs()
  return Observable.inext, self, 0
end


return Observable
