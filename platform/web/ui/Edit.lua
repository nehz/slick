local platform = require('platform').is('web')
local Observable = require('core.Observable')


controller {
  function()
    function scope.set_text(text)
      scope['$element'].value = tostring(text or '')
    end

    local function on_change()
      local watcher_id = scope['$watchers'].attr[1].id
      Observable.set_index(attr, 1, scope['$element'].value, watcher_id)
    end

    scope.set_text(attr[1])
    platform.event_listener(scope, 'onchange', on_change)
    platform.event_listener(scope, 'onkeypress', on_change)
    platform.event_listener(scope, 'onpaste', on_change)
    platform.event_listener(scope, 'oninput', on_change)
  end,

  [attr[1]] = function(v)
    scope.set_text(v)
  end,

  ['$new'] = function()
    local element = js.global.document:createElement('input')
    element.className = 'ui edit'
    return element
  end,
}
