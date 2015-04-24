require('core.env')
local Dispatcher = require('core.Dispatcher')


describe('Dispatcher', function()
  it('should be [Dispatcher] instance', function()
    local d = Dispatcher.new(10)
    assert.is.equal(getmetatable(d), Dispatcher)
  end)

  it('should assign item', function()
    local d = Dispatcher.new(10)
    local a, a_key = Dispatcher.assign(d, 1)
    local b, b_key = Dispatcher.assign(d, 2)

    assert.is.equal(Dispatcher.get(d, a, a_key), 1)
    assert.is.equal(Dispatcher.get(d, b, b_key), 2)
  end)

  it('should remove item', function()
    local d = Dispatcher.new(10)
    local a, a_key = Dispatcher.assign(d, 1)
    local b, b_key = Dispatcher.assign(d, 2)

    assert.is.equal(Dispatcher.get(d, a, a_key), 1)
    assert.is.equal(Dispatcher.get(d, b, b_key), 2)
    assert.is.equal(d.n, 2)

    assert.is.equal(Dispatcher.remove(d, a, a_key), 1)
    assert.is.equal(Dispatcher.remove(d, b, b_key), 2)
    assert.is.equal(d.n, 0)
    assert.is.equal(d[a], nil)
    assert.is.equal(d[b], nil)
  end)

  it('should be reassignable', function()
    local d = Dispatcher.new(2)
    local a, a_key = Dispatcher.assign(d, 1)
    local b, b_key = Dispatcher.assign(d, 2)

    assert.is.equal(Dispatcher.get(d, a, a_key), 1)
    assert.is.equal(Dispatcher.get(d, b, b_key), 2)

    assert.is.equal(Dispatcher.remove(d, a, a_key), 1)
    assert.is.equal(Dispatcher.remove(d, b, b_key), 2)
    assert.is.equal(d[a], nil)
    assert.is.equal(d[b], nil)

    a, a_key = Dispatcher.assign(d, 3)
    b, b_key = Dispatcher.assign(d, 4)
    assert.is.equal(Dispatcher.get(d, a, a_key), 3)
    assert.is.equal(Dispatcher.get(d, b, b_key), 4)
    assert.is.equal(d.n, d.max, 2)
  end)

  it('should not assign item if full', function()
    local d = Dispatcher.new(2)
    local a, a_key = Dispatcher.assign(d, 1)
    local b, b_key = Dispatcher.assign(d, 2)

    assert.has_error(function() Dispatcher.assign(d, 3) end,
      'Unable to allocate')

    assert.is.equal(Dispatcher.get(d, a, a_key), 1)
    assert.is.equal(Dispatcher.get(d, b, b_key), 2)

    assert.is.equal(Dispatcher.remove(d, b, b_key), 2)
    assert.is.equal(Dispatcher.get(d, a, a_key), 1)
    assert.is.equal(d.n, 1)

    b = Dispatcher.assign(d, 3)
    assert.is.equal(Dispatcher.get(d, a, a_key), 1)
    assert.is.equal(Dispatcher.get(d, b, b_key), 3)
    assert.is.equal(d.n, 2)
  end)

  it('should prevent access to items that no longer exist', function()
    local d = Dispatcher.new(2)
    local a, a_key = Dispatcher.assign(d, 1)
    assert.is.equal(Dispatcher.remove(d, a, a_key), 1)
    assert.is.equal(d.n, 0)

    assert.has_error(function() Dispatcher.check(d, a, a_key) end,
      'No item')
    assert.has_error(function() Dispatcher.get(d, a, a_key) end,
      'No item')
    assert.has_error(function() Dispatcher.remove(d, a, a_key) end,
      'No item')
  end)

  it('should require key', function()
    local d = Dispatcher.new(2)
    local a, a_key = Dispatcher.assign(d, 1)

    assert.has_error(function() Dispatcher.check(d, a, a_key + 1) end,
      'Invalid key')
    Dispatcher.check(d, a, a_key)

    assert.has_error(function() Dispatcher.get(d, a, a_key + 1) end,
      'Invalid key')
    assert.is.equal(Dispatcher.get(d, a, a_key), 1)

    assert.has_error(function() Dispatcher.remove(d, a, a_key + 1) end,
      'Invalid key')
    assert.is.equal(Dispatcher.remove(d, a, a_key), 1)
    assert.is.equal(d.n, 0)
  end)
end)
