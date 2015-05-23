local platform = require('platform').is('android')

local java = require('platform.android.java')
local TextView = java.import('android.widget.TextView')


controller {
  function()
    function scope.set_text(text)
      scope['$element']:setText(tostring(text or ''))
    end
    scope.set_text(attr[1])
  end,

  [attr[1]] = function(v)
    scope.set_text(v)
  end,

  ['$new'] = function(component, parent)
    return TextView(platform.activity)
  end
}
