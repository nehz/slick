require('core.env')
local Dispatcher = require('core.Dispatcher')

local MAX_DISPATCH_ITEMS = 1e6

local platform = {
  dispatcher = Dispatcher.new(MAX_DISPATCH_ITEMS)
}


function platform.set(name)
  assert(not platform.name, 'Platform already set:', platform.name)
  platform.name = name
  require('platform.' .. name)
  return platform
end


function platform.is(name)
  assert(platform.name, 'Platform not set')
  assert(platform.name == name, 'Platform mismatch:', platform.name, name)
  return platform
end


function platform.init(entry, ...)
  assert(platform.name, 'Platform not set')
  platform.bootstrap(...)

  local status, err = xpcall(platform.push_component, function(err)
    return debug.traceback(err)
  end, entry)

  if not status then
    error(err)
  end
end


return platform
