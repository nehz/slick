require('core.env')
local Dispatcher = require('core.Dispatcher')


describe('Dispatcher', function()
  it('should be [Dispatcher] instance', function()
    local d = Dispatcher.new(10)
    assert.is.equal(getmetatable(d), Dispatcher)
  end)

  it('should assign item', function()
    local d = Dispatcher.new(10)
    local a = Dispatcher.assign(d, 1)
    local b = Dispatcher.assign(d, 2)

    assert.is.equal(d[a], 1)
    assert.is.equal(d[b], 2)
  end)

  it('should remove item', function()
    local d = Dispatcher.new(10)
    local a = Dispatcher.assign(d, 1)
    local b = Dispatcher.assign(d, 2)

    assert.is.equal(d[a], 1)
    assert.is.equal(d[b], 2)
    assert.is.equal(d.n, 2)

    assert.is.equal(Dispatcher.remove(d, a), 1)
    assert.is.equal(Dispatcher.remove(d, b), 2)
    assert.is.equal(d.n, 0)
    assert.is.equal(d[a], nil)
    assert.is.equal(d[b], nil)
    assert.is.same(d, {max = 10, next = d.next, n = 0})
  end)

  it('should be reassignable', function()
    local d = Dispatcher.new(2)
    local a = Dispatcher.assign(d, 1)
    local b = Dispatcher.assign(d, 2)

    assert.is.equal(d[a], 1)
    assert.is.equal(d[b], 2)

    assert.is.equal(Dispatcher.remove(d, a), 1)
    assert.is.equal(Dispatcher.remove(d, b), 2)
    assert.is.equal(d[a], nil)
    assert.is.equal(d[b], nil)

    a = Dispatcher.assign(d, 3)
    b = Dispatcher.assign(d, 4)
    assert.is.equal(d[a], 3)
    assert.is.equal(d[b], 4)
    assert.is.equal(d.n, d.max, 2)
    assert.is.same(d, {[a] = 3, [b] = 4, max = 2, next = d.next, n = 2})
  end)

  it('should not assign item if full', function()
    local d = Dispatcher.new(2)
    local a = Dispatcher.assign(d, 1)
    local b = Dispatcher.assign(d, 2)

    assert.has_error(function() Dispatcher.assign(d, 3) end,
      'Unable to allocate')

    assert.is.equal(d[a], 1)
    assert.is.equal(d[b], 2)
    assert.is.same(d, {[a] = 1, [b] = 2, max = 2, next = d.next, n = 2})

    assert.is.equal(Dispatcher.remove(d, b), 2)
    assert.is.equal(d[a], 1)
    assert.is.equal(d[b], nil)
    assert.is.equal(d.n, 1)

    b = Dispatcher.assign(d, 3)
    assert.is.equal(d[a], 1)
    assert.is.equal(d[b], 3)
    assert.is.equal(d.n, 2)
    assert.is.same(d, {[a] = 1, [b] = 3, max = 2, next = d.next, n = 2})
  end)
end)
