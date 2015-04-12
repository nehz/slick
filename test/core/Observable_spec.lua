require('core.env')
local Observable = require('core.Observable')


describe('Observable', function()
  it('should be [Observable] type', function()
    local o = Observable.new()
    assert.is_true(Observable.is_observable(o))
    assert.is_false(Observable.is_table(o))
  end)

  it('can be unwrapped', function()
    local o = Observable.new(1)
    assert.is.same(Observable.unwrap(o), 1)
  end)

  describe('table value', function()
    it('should be accessible', function()
      local o = Observable.new({a = 1})
      assert.is.equal(o.a, 1)
      assert.is_nil(o.b)
      o.a = 2
      o.b = 1
      o.c = false
      o.d = 'test'
      assert.is.equal(o.a, 2)
      assert.is.equal(o.b, 1)
      assert.is.equal(o.c, false)
      assert.is.equal(o.d, 'test')
    end)

    it('should convert assigned tables to [Observable]', function()
      local o = Observable.new({a = 1, b = {}})
      local c = {}
      o.c = c
      assert.is_false(Observable.is_observable(o.a))
      assert.is_true(Observable.is_observable(o.b))
      assert.is_true(Observable.is_observable(c))
      assert.is_true(Observable.is_observable(o.c))
    end)

    it('should have the correct length', function()
      local o = Observable.new({a = {1, 2, 3, 4, 5}})
      local b = Observable.new({1, 2, 3, 4, 5, 6})
      assert.is.equal(#o.a, 5)
      assert.is.equal(#b, 6)
    end)

    it('should be iterable with pairs', function()
      local o = Observable.new({a = 1, b = false, c = 'test', d = {e = 1}})
      local num_keys = 0
      for k, v in pairs(o) do
        if k == 'a' then assert.is.equal(v, 1)
        elseif k == 'b' then assert.is.equal(v, false)
        elseif k == 'c' then assert.is.equal(v, 'test')
        elseif k == 'd' then assert.is.equal(v.e, 1)
        else error() end
        num_keys = num_keys + 1
      end
      assert.is.equal(num_keys, 4)
    end)

    it('should be iterable with ipairs', function()
      local o = Observable.new({1, false, 'test', {e = 1}})
      local iter = ipairs(o)
      local i, v

      i, v = iter(o, 0)
      assert.is.equal(i, 1)
      assert.is.equal(v, 1)

      i, v = iter(o, 1)
      assert.is.equal(i, 2)
      assert.is.equal(v, false)

      i, v = iter(o, 2)
      assert.is.equal(i, 3)
      assert.is.equal(v, 'test')

      i, v = iter(o, 3)
      assert.is.equal(i, 4)
      assert.is.equal(v.e, 1)
    end)

    it('should be iterable with Observable.spairs', function()
      local o = Observable.new({a = 1, b = false, c = 'test', d = {e = 1}})
      local num_keys = 0
      for k, s in Observable.spairs(o) do
        if k == 'a' then
          assert.is.equal(s, Observable.index(o, 'a'))
          assert.is.equal(Observable.unwrap(s), 1)
        elseif k == 'b' then
          assert.is.equal(s, Observable.index(o, 'b'))
          assert.is.equal(Observable.unwrap(s), false)
        elseif k == 'c' then
          assert.is.equal(s, Observable.index(o, 'c'))
          assert.is.equal(Observable.unwrap(s), 'test')
        elseif k == 'd' then
          assert.is.equal(s, Observable.index(o, 'd'))
          assert.is.equal(s.e, 1)
        else error() end
        num_keys = num_keys + 1
      end
      assert.is.equal(num_keys, 4)
    end)
  end)

  it('should get change notifications', function()
    local done = {false, false}
    local o = Observable.new({a = 1})
    local a = Observable.index(o, 'a')

    Observable.watch(o, 'a', function(v)
      assert.is.equal(v, 1)
      assert.is.equal(coroutine.yield(), 2)
      assert.is.equal(coroutine.yield(), 3)
      assert.is.equal(coroutine.yield(), false)
      assert.is.equal(coroutine.yield(), 'test')
      assert.is.equal(coroutine.yield().b, 1)
      assert.is.equal(coroutine.yield().b, 2)
      done[1] = true
    end, nil, true)

    Observable.watch(o, nil, function(v, idx)
      assert.is.same({v, idx}, {1, 'a'})
      v, idx = coroutine.yield()
      assert.is.same({v, idx}, {2, 'a'})
      v, idx = coroutine.yield()
      assert.is.same({v, idx}, {3, 'a'})
      v, idx = coroutine.yield()
      assert.is.same({v, idx}, {1, 'b'})
      v, idx = coroutine.yield()
      assert.is.same({v, idx}, {false, 'a'})
      v, idx = coroutine.yield()
      assert.is.same({v, idx}, {'test', 'a'})

      v, idx = coroutine.yield()
      assert.is.same({v.b, idx}, {1, 'a'})
      v, idx = coroutine.yield()
      assert.is.same({v.b, idx}, {2, 'a'})

      v, idx = coroutine.yield()
      assert.is.same({v, idx}, {5, 'c'})
      done[2] = true
    end, nil, true)

    o.a = 1
    o.a = 2
    Observable.set(a, 3)
    o.b = 1
    o.a = false
    o.a = 'test'
    o.a = {b = 1}
    Observable.set(a, {b = 2})
    o.c = 5

    assert.is.same(done, {true, true})
  end)

  it('should not store [Observable] unless it is a slot', function()
    local o = Observable.new(1)
    assert.has.error(function()
      Observable.new(o)
    end)
    local s = Observable.new(o, {slot = true})
  end)

  it('should merge assigned table', function()
    local o = Observable.new({a = 1, b = {2, 3}})
    local slot_a = Observable.index(o, 'a')
    local slot_b = Observable.index(o, 'b')

    assert.is.equal(o.a, 1)
    assert.is.same({o.b[1], o.b[2], o.b[3]}, {2, 3})
    assert.is.equal(Observable.index(o, 'c'), nil)

    Observable.set(o, {a = 4, b = {5, 6}, c = 7})
    assert.is.equal(o.a, 4)
    assert.is.same({o.b[1], o.b[2], o.b[3]}, {5, 6})
    assert.is.equal(o.c, 7)
    assert.is.equal(Observable.index(o, 'a'), slot_a)
    assert.is.equal(Observable.index(o, 'b'), slot_b)
    assert.is_not.equal(Observable.index(o, 'c'), nil)
  end)
end)
