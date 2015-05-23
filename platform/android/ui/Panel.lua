local platform = require('platform').is('android')
local Panel = require('platform.common.ui.Panel')

local java = require('platform.android.java')
local LinearLayout = java.import('android.widget.LinearLayout')
local LayoutParams = java.import('android.view.ViewGroup$LayoutParams')


controller {
  function(loop)
    local element = scope['$element']

    function scope.append_child(child)
      element:addView(child.element)
    end

    function scope.insert_child(child, idx)
      element:addView(child.element, idx - 1)
    end

    function scope.remove_child(child)
      element:removeView(child.element)
    end

    element:setOrientation(1)
    element:setLayoutParams(LayoutParams(-1, -2))

    Panel.init(attr, scope, loop)
  end,

  [attr.loop] = Panel.watch,

  ['$new'] = function()
    return LinearLayout(platform.activity)
  end,

  ['$destroy'] = function()
    Panel.clear(scope)
  end,
}
