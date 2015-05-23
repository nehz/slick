local platform = require('platform').is('android')

local java = require('platform.android.java')
local Button = java.import('android.widget.Button')


controller {
  function()
    function scope.set_text()
      scope['$element']:setText(tostring(attr[1] or 'Button'))
    end
    scope.set_text(attr[1])
  end,

  [attr[1]] = function(v)
    scope.set_text(v)
  end,

  ['$new'] = function(component)
    return Button(platform.activity)
  end
}
