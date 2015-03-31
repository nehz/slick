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


function bindfenv(f, env, global_env, access_global)
  if global_env == true then global_env = _G end
  if access_global == true then setmetatable(global_env, {__index = _G}) end
  return function(...)
    local new_env = setmetatable(env, {__index = global_env})
    local t = coroutine.create(f)
    local args = table.pack(...)

    while true do
      local old_env = getfenv(f)
      setfenv(f, new_env)
      local res = table.pack(coroutine.resume(t, table.unpack(args, 1, args.n)))
      setfenv(f, old_env)

      if not res[1] then
        local e = res[2]
        if type(e) == 'table' then
          e.traceback = debug.traceback(t)
          error(e)
        else
          assert(type(e) == 'string')
          error(debug.traceback(t, e))
        end
      end

      if coroutine.status(t) == 'dead' then return res end
      args = table.pack(coroutine.yield(table.unpack(res, 2, res.n)))
    end
  end
end
