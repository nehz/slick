function table.insert(o, ...)
  local Observable = require('core.Observable')
  local nargs = select('#', ...)
  local t
  if Observable.is_observable(o) then
    t = Observable.unwrap_indexable(o)
  else
    t = o
  end

  local n = #o
  if nargs == 1 then
    local v = ...
    o[n + 1] = v
    return v
  elseif nargs == 2 then
    local pos, v = ...
    if not (1 <= pos and pos <= n + 1) then
      error('table.insert position out of bounds', 2)
    end
    for i = n, pos, -1 do
      if Observable.is_observable(t[i]) then
        assert(t[i]['$slot'])
        t[i]['$idx'] = i + 1
      end
      t[i + 1] = t[i]
    end
    t[pos] = nil
    o[pos] = v
    return v
  else
    error('table.insert takes 2 or 3 parameters', 2)
  end
end


function table.copy(t, iter, deep, copy)
  copy = copy or {}
  iter = iter or pairs
  for k, v in iter(t) do
    if deep and type(v) == 'table' then
      copy[k] = table.copy(v, iter, deep)
    else
      copy[k] = v
    end
  end
  return copy
end


function table.icopy(t, deep, copy)
  return table.copy(t, ipairs, deep, copy)
end


function table.keys(t)
  local keys = {}
  for k in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end


function table.len(t)
  return #table.keys(t)
end


function table.map(t, f, iter)
  local results = {}
  iter = iter or pairs
  for k, v in iter(t) do
    results[k] = f(v, k)
  end
  return results
end


function table.imap(t, f)
  return table.map(t, f, ipairs)
end


function table.print(t)
  local Observable = require('core.Observable')

  local function tprint(v, indent, visited)
    if not v then
      print('nil')
      return
    end
    if not visited then
      print(tostring(v))
    end
    if type(v) ~= 'table' then
      return
    end

    visited = visited or {}
    indent = (indent or 0) + 2

    local iter = Observable.is_observable(v) and Observable.spairs or pairs
    for key, value in iter(v) do
      local fmt
      if type(value) == 'string' then
        fmt = '%' .. indent .. "s[%s] => '%s'"
      else
        fmt = '%' .. indent .. 's[%s] => %s'
      end
      print(string.format(fmt, '', tostring(key), tostring(value)))

      if type(value) == 'table' and not visited[value] then
        if Observable.is_observable(value) and
            not Observable.is_indexable(value) then
          goto continue
        end
        visited[value] = true
        tprint(value, indent, visited)
      end
      :: continue ::
    end
  end

  return tprint(t)
end


function table.vivify(t, keys, n)
  assert(type(t) == 'table', 'argument #1 is not a table')
  assert(type(keys) == 'table', 'argument #2 is not a table')

  n = n or #keys
  assert(type(n) == 'number', 'argument #3 is not a number or nil')

  for i = 1, n do
    local v = keys[i]
    if t[v] == nil then t[v] = {} end
    t = t[v]
  end
  return t
end
