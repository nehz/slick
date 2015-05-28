local platform = require('platform').is('android')
local Observable = require('core.Observable')

local java = require('platform.android.java')
local EditText = java.import('android.widget.EditText')


controller {
  function()
    function scope.set_text(text)
      scope['$element']:setText(tostring(text or ''))
    end

    scope.set_text(attr[1])
    platform.event_listener(scope, 'addTextChangedListener', function(text)
      local watcher_id = scope['$watchers'].attr[1].id
      Observable.set_index(attr, 1, text, watcher_id)
    end)
  end,

  [attr[1]] = function(v)
    scope.set_text(v)
  end,

  ['$new'] = function()
    return EditText(platform.activity)
  end
}
