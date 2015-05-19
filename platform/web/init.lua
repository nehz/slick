local platform = require('platform').is('web')
local Component = require('core.Component')
local Dispatcher = require('core.Dispatcher')


function platform.loadfile(name)
  local xhr = js.new(window.XMLHttpRequest)
  xhr:open('GET', name, false)
  xhr:send()
  if xhr.status ~= 200 then
    error(xhr.statusText .. ' ' .. name)
  end
  return load(xhr.responseText, name)
end


function platform.push_component(component)
  local component, element = Component.build(component)
  platform.root:appendChild(element)
end


function platform.build(component)
  -- Bind general events
  platform.event_listener(component.scope, 'onclick', function()
    component.env.trigger('click')
  end)
end


function platform.event_listener(scope, event, listener)
  local id, key = Dispatcher.assign(platform.dispatcher, listener)
  scope['$dispatch'][id] = key
  scope['$element'][event] = function(...)
    local listener = Dispatcher.get(platform.dispatcher, id, key)
    if listener then
      listener(...)
    end
  end
end


function platform.bootstrap(root)
  loadfile = platform.loadfile
  platform.root = root
end


return platform
