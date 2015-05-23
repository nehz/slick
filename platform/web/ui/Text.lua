local platform = require('platform').is('web')
local Observable = require('core.Observable')


controller {
  function()
    function scope.set_text(text)
      scope['$element'].innerText = tostring(text or '')
      scope['$element'].textContent = tostring(text or '')
    end
    scope.set_text(attr[1])
  end,

  [attr[1]] = function(v)
    scope.set_text(v)
  end,

  ['$new'] = function()
    local element = js.global.document:createElement('span')
    element.className = 'ui text'
    return element
  end,
}
