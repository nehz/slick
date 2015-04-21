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

    visited = visited or {}
    indent = (indent or 0) + 2

    if type(v) == 'table' then
      local iter = Observable.is_observable(v) and Observable.spairs or pairs
      for key, value in iter(v) do
        local fmt = '%' .. indent .. 's[%s] => %s'
        print(string.format(fmt, '', tostring(key), tostring(value)))

        if Observable.is_indexable(value) and not visited[value] then
          visited[value] = true
          tprint(value, indent, visited)
        end
      end
    end
  end

  return tprint(t)
end


function table.vivify(t, keys, n)
  for i = 1, n or #keys do
    local v = keys[i]
    if t[v] == nil then t[v] = {} end
    t = t[v]
  end
  return t
end
