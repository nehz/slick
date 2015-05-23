local platform = require('platform').is('web')


controller {
  function()
    function scope.set_text(text)
      scope['$element'].innerText = tostring(text or 'Button')
      scope['$element'].textContent = tostring(text or 'Button')
    end
    scope.set_text(attr[1])
  end,

  [attr[1]] = function(v)
    scope.set_text(v)
  end,

  ['$new'] = function()
    local element = js.global.document:createElement('button')
    element.className = 'ui button'
    return element
  end,
}
