local cache = setmetatable({}, {__mode = 'k'})


local function find_env(f)
  local up = 0
  local name, val

  if type(f) == 'number' then
    assert(f >= 0, 'Function level must be positive')
    assert(f ~= 0, 'Thread environments not supported')
    f = debug.getinfo(f + 2, 'f').func
  end
  assert(type(f) == 'function', '[function] or [number] expected')
  assert(debug.getinfo(f).what ~= 'C', 'C function not supported')

  repeat
    up = up + 1
    name, val = debug.getupvalue(f, up)
  until name == '_ENV' or name == nil

  return up, val, f
end


setfenv = rawget(_G, 'setfenv') or function(f, t)
  assert(f and t)
  local up, val, f = find_env(f)
  if val then
    debug.upvaluejoin(f, up, function() return t end, 1)
  else
    cache[f] = t
  end
  return f
end


getfenv = rawget(_G, 'getfenv') or function(f)
  assert(f)
  local _, val, f = find_env(f)
  if val then return val end

  if not cache[f] then cache[f] = {} end
  return cache[f]
end
