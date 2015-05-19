local platform = require('platform').is('web')
local Observable = require('core.Observable')


controller {
  function()
    scope['$element'].value = tostring(attr[1] or '')

    local function on_change()
      local element = scope['$element']
      if attr.text == element.value then return end
      Observable.set_index(attr, 1, element.value, scope['$watchers'].attr[1].id)
    end

    platform.event_listener(scope, 'onchange', on_change)
    platform.event_listener(scope, 'onkeypress', on_change)
    platform.event_listener(scope, 'onpaste', on_change)
    platform.event_listener(scope, 'oninput', on_change)
  end,

  [attr[1]] = function(v)
    if v then scope['$element'].value = tostring(v) end
  end,

  ['$new'] = function()
    local element = js.global.document:createElement('input')
    element.className = 'ui edit'
    return element
  end,
}
