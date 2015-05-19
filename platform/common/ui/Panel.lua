local platform = require('platform')
local Observable = require('core.Observable')
local Component = require('core.Component')
local Panel = {}


function Panel.build_child(scope, idx, value, id)
  local loop = Observable.new({key = idx, value = value})
  local as = {}
  if scope['$loop'] then
    setmetatable(as, {__index = scope['$loop']['$as']})
  end
  Observable.set_metatable(loop, {__index = as})
  rawset(loop, '$as', as)

  local as_ir = scope['$component'].args.as
  if as_ir then
    as = setmetatable(table.vivify(as, as_ir), {})
    as.key = Observable.index(loop, 'key', true)
    as.value = Observable.index(loop, 'value', true)
  end

  local panel = 'platform.' .. platform.name .. '.ui.Panel'
  local child = Component.get(panel, nil, scope.args)
  child = Component.build(child, scope['$parent'], loop)

  -- Create
  if not scope.children[idx] then
    scope.append_child(child)
    scope.children[idx] = child
    return
  end

  scope.insert_child(idx, child)

  -- Replace
  if id ~= table.insert then
    assert(scope.children[idx])
    Panel.delete_child(scope, idx)
    scope.children[idx] = child
    return
  end

  -- Insert
  assert(type(idx) == 'number')
  for i = idx, #scope.children do
    local loop = scope.children[i].scope['$loop']
    assert(loop.key == i)
    loop.key = i + 1
  end
  table.insert(scope.children, idx, nil)
  scope.children[idx] = child
end


function Panel.delete_child(scope, idx)
  local child = scope.children[idx]
  if child then
    scope.remove_child(idx)
    Component.destroy(child)
    scope.children[idx] = nil
  end
end


function Panel.clear(scope)
  for idx in pairs(scope.children) do
    Panel.delete_child(scope, idx)
  end
  scope.children = {}
end


function Panel.init(attr, scope, loop)
  scope.children = {}
  scope['$loop'] = loop

  if scope['$component'].args.loop then
    -- Loop container panel
    scope.args = table.copy(scope['$component'].args)
    assert(scope.args.loop)
    scope.args.loop = nil

    if type(attr.loop) == 'table' then
      for idx, v in pairs(attr.loop) do
        Panel.build_child(scope, idx, v)
      end
    end
  else
    -- Normal panel
    for _, child in ipairs(attr) do
      local child = Component.get(child)
      child.scope['$loop'] = loop
      Component.build(child, scope['$parent'], loop)
      scope.append_child(child)
      table.insert(scope.children, child)
    end
  end
end


function Panel.watch(value, idx, id)
  if idx == nil then
    Panel.clear(scope)
    return
  end

  if value == nil then
    Panel.delete_child(scope, idx)
    return
  end

  Panel.build_child(scope, idx, value, id)
end


return Panel
