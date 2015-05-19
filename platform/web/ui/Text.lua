local Observable = require('core.Observable')


controller {
  function()
    function scope.set_text(text)
      scope['$element'].innerText = text
      scope['$element'].textContent = text
    end
    scope.set_text(tostring(attr[1] or ''))
  end,

  [attr[1]] = function(v)
    if v then scope.set_text(tostring(v)) end
  end,

  ['$new'] = function()
    local element = js.global.document:createElement('span')
    element.className = 'ui text'
    return element
  end,
}
