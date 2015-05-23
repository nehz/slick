local platform = require('platform').is('android')
local Component = require('core.Component')
local Dispatcher = require('core.Dispatcher')

local java = require('platform.android.java')
local Activity = java.import('android.app.Activity')
local ScrollView = java.import('android.widget.ScrollView')
local EventListener = java.import('com.slick.core.EventListener')

platform.activity_stack = {}


function platform.loadfile(name)
  local file = _internal.inflate('assets/' .. name)
  if not file then
    return file, 'No such file: ' .. name
  end
  return load(file, name)
end


function platform.print(...)
  local args = table.pack(...)
  args = table.imap(args, function(v) return tostring(v) end)
  _internal.log_info(table.concat(args, ' '))
end


function platform.push_component(component)
  table.insert(platform.activity_stack, platform.activity)
  local component = Component.build(component)

  local wrapper = ScrollView(platform.activity)
  wrapper:setVerticalScrollBarEnabled(false)
  wrapper:setHorizontalScrollBarEnabled(false)
  wrapper:addView(component.element)

  platform.activity:setContentView(wrapper)
end


function platform.build(component)
  if component.id then
    -- Bind general events
    platform.event_listener(component.scope, 'setOnClickListener', function()
      component.env.trigger('click')
    end)
  end
end


function platform.event_listener(scope, event, listener)
  local id, key = Dispatcher.assign(platform.dispatcher, listener)
  local element = scope['$element']
  scope['$dispatch'][id] = key
  element[event](element, EventListener(id, key))
end


function platform.on_event(id, key, ...)
  local listener = Dispatcher.get(platform.dispatcher, id, key)
  if listener then
    listener(...)
  end
end


function platform.bootstrap(activity)
  loadfile = platform.loadfile
  print = platform.print

  assert(activity)
  platform.activity = java.reference(activity, Activity)
end


return platform
