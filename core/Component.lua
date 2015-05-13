local platform = require('platform')

local Observable = require('core.Observable')
local IndexRecorder = require('core.IndexRecorder')
local Dispatcher = require('core.Dispatcher')

local Component = {
  instances = setmetatable({}, {__mode = 'v'}),
  cache = {},
}

local loader_globals = {
  scope = IndexRecorder.new('scope'),
  attr = IndexRecorder.new('attr'),
  loop = IndexRecorder.new('loop'),
  ui = IndexRecorder.new('ui'),
  component = IndexRecorder.new('component'),
  id = IndexRecorder.new('id'),
}
setmetatable(loader_globals, {__index = _G})


local function loader(what, definition)
  return function(x)
    definition[what] = x
  end
end


function Component.load_definition(name)
  assert(type(name) == 'string')

  local path = name:gsub('%.', '/') .. '.lua'
  local definition = Component.cache[path]
  if definition then return definition end

  local f, err = loadfile(path)
  if not f then error(err) end

  definition = {
    name = name,
    path = path,
    view = {},
    controller = {},
    style = {},
    tests = {},
  }

  local loader_env = {
    view = loader('view', definition),
    controller = loader('controller', definition)
  }

  bindfenv(f, loader_env, loader_globals)()
  Component.cache[path] = definition
  return definition
end


function Component.get(component, id, args)
  assert(getmetatable(component) ~= Component)
  if getmetatable(component) == IndexRecorder then
    assert(not id and not args)
    local info = IndexRecorder.info(component)
    local path = table.concat(component, '.')
    local prefix

    if info.type == 'ui' then
      prefix = 'platform.' .. platform.name .. '.ui.'
    elseif info.type == 'component' then
      prefix = 'app.components.'
    else
      error('Invalid component: ' .. path)
    end
    return Component.get(prefix .. path, info.id, info.args[1])
  end

  local attr = Observable.new({})
  local scope = Observable.new({})
  local component = {
    id = id,
    args = args or {},
    definition = Component.load_definition(component),
    attr = attr,
    scope = scope,
    env = {attr = attr, scope = scope},
  }
  return setmetatable(component, Component)
end


function Component.new(component, parent, ...)
  if getmetatable(component) ~= Component then
    component = Component.get(component)
  end

  table.insert(Component.instances, component)
  local attr = component.attr
  local scope = component.scope

  rawset(scope, '$parent', parent)
  rawset(scope, '$component', component)
  rawset(scope, '$id', component.id)
  rawset(scope, '$listeners', {})
  rawset(scope, '$dispatch', {})

  function component.env.trigger(event_name, ...)
    local listeners = scope['$listeners'][event_name]
    if not listeners then return end
    for _, listener in ipairs(listeners) do
      listener(event_name, ...)
    end
  end

  -- Init component attrs from args
  if parent then
    for name, arg in pairs(component.args) do
      -- Resolve args
      if getmetatable(arg) ~= IndexRecorder then
        attr[name] = arg
        goto continue
      end

      local info = IndexRecorder.info(arg)
      local x =
        (info.type == 'scope' and parent.scope) or
        (info.type == 'attr' and parent.attr) or
        (info.type == 'loop' and (scope['$loop'] or {})) or nil

      if x then
        x = table.vivify(x, arg, #arg - 1)
        if Observable.is_observable(x) then
          local slot = Observable.index(x, arg[#arg], true)
          Observable.set_slot(attr, name, slot)
          if info.init ~= nil and info.type == 'scope' then
            attr[name] = info.init
          end
        else
          attr[name] = x[arg[#arg]]
        end
      else
        assert(info.type == 'ui' or info.type == 'component', info.type)
        attr[name] = arg
      end
      :: continue ::
    end
  end

  -- Register attr watchers
  for ir, watcher in pairs(component.controller) do
    if getmetatable(ir) ~= IndexRecorder then goto continue end
    local info = IndexRecorder.info(ir)

    if info.type == 'attr' then
      if #ir ~= 1 then
        local attr = info.type .. '.' .. table.concat(ir, '.')
        error('Invalid attr watch: ' .. attr)
      end
      Observable.watch(attr, ir[1], bindfenv(watcher, component.env, true))
    elseif info.type == 'scope' then
      error('Scope watch not supported')
    elseif info.type ~= 'id' then
      error('Invalid watch type: ' .. info.type)
    end
    :: continue ::
  end

  -- Register event listeners
  if parent then
    local parent_controller = parent.scope['$component'].controller
    for ir, listener in pairs(parent_controller or {}) do
      if getmetatable(ir) ~= IndexRecorder then goto continue end
      local info = IndexRecorder.info(ir)
      if info.type ~= 'id' then goto continue end

      local id = info.type .. '.' .. table.concat(ir, '.')
      if #ir >= 3 then
        error('Invalid listener for: ' .. id)
      end

      if ir[1] ~= component.id then goto continue end
      if #ir == 1 then
        if type(listener) ~= 'table' then
          error('Expected listener table for: ' .. id)
        end
        for event, f in pairs(listener) do
          local listeners = table.vivify(scope, {'$listeners', event})
          table.insert(listeners, bindfenv(f, parent.env, true))
        end
      else
        if type(listener) ~= 'function' then
          error('Expected listener function for: ' .. id)
        end
        local listeners = table.vivify(scope, {'$listeners', ir[2]})
        table.insert(listeners, bindfenv(listener, parent.env, true))
      end
      :: continue ::
    end
  end

  local controller = component.controller
  local new = controller and controller['$new']
  if new then
    return component, new(component, parent, ...)
  end
  return component
end


function Component.init(component, ...)
  local controller = component.controller
  local constructor = controller and controller[1]
  if constructor then
    bindfenv(constructor, component.env, true)(...)
  end
end


function Component.build(component, parent, ...)
  local component, element = Component.new(component, parent, ...)

  -- Build view using Panel
  if type(component.view) == 'table' and #component.view > 0 then
    local panel = 'platform.' .. platform.name .. '.ui.Panel'
    if component.name ~= panel then
      panel = Component.get(panel, nil, component.view)
      panel, element = Component.build(panel, component, ...)
      rawset(component.scope, '$panel', panel)
    end
  end

  assert(element)
  rawset(component.scope, '$element', element)

  -- Platform specific build hook
  if platform.build then
    platform.build(component)
  end

  Component.init(component, ...)
  return component, element
end


function Component.destroy(component)
  if component.scope['$panel'] then
    Component.destroy(component.scope['$panel'])
  end

  local controller = component.controller
  if controller and controller['$destroy'] then
    bindfenv(controller['$destroy'], component.env, true)()
  end

  if platform.destroy_element then
    platform.destroy_element(component.scope['$element'])
  end
  component.scope['$element'] = nil
  component.scope['$destroyed'] = true

  for id, key in pairs(component.scope['$dispatch']) do
    Dispatcher.remove(platform.dispatcher, id, key)
  end
end


function Component:__index(name)
  assert(rawget(self, 'definition'))
  return self.definition[name]
end


function Component:__tostring()
  if self.id then
    return string.format('Component(%s:%s)', self.name, self.id)
  else
    return string.format('Component(%s)', self.name)
  end
end


return Component