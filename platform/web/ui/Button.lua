local platform = require('platform').is('web')


controller {
  function()
    function scope.set_text(text)
      scope['$element'].innerText = text or 'Button'
      scope['$element'].textContent = text or 'Button'
    end
    scope.set_text(attr[1])
  end,

  [attr[1]] = function(v)
    scope.set_text(v)
  end,

  ['$new'] = function(component, parent, activity)
    local element = js.global.document:createElement('button')
    element.className = 'ui button'
    return element
  end,
}
