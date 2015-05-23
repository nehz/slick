local platform = require('platform').is('web')
local Panel = require('platform.common.ui.Panel')


controller {
  function(loop)
    function scope.append_child(child)
      scope['$element']:appendChild(child.element)
    end

    function scope.insert_child(child, idx)
      scope['$element']:insertBefore(child.element, scope.children[idx].element)
    end

    function scope.remove_child(child)
      scope['$element']:removeChild(child.element)
    end

    Panel.init(attr, scope, loop)
  end,

  [attr.loop] = Panel.watch,

  ['$new'] = function()
    local element = js.global.document:createElement('div')
    element.className = 'ui panel'
    return element
  end,

  ['$destroy'] = function()
    Panel.clear(scope)
  end,
}
