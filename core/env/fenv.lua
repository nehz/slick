local cache = setmetatable({}, {__mode = 'k'})

local function find_env(f)
  local up = 0
  local name, val

  f = (type(f) == 'function' and f or debug.getinfo(f + 1, 'f').func)
  repeat
    up = up + 1
    name, val = debug.getupvalue(f, up)
  until name == '_ENV' or name == nil

  return up, val
end


setfenv = rawget(_G, 'setfenv') or function(f, t)
  assert(f and t)
  local up, val = find_env(f)
  if val then
    debug.upvaluejoin(f, up, function() return t end, 1)
  else
    cache[f] = t
  end
end


getfenv = rawget(_G, 'getfenv') or function(f)
  assert(f)
  if cache[f] then return cache[f] end
  cache[f] = f

  local val = select(2, find_env(f))
  if val then return val end

  if not cache[f] then cache[f] = {} end
  return cache[f]
end
