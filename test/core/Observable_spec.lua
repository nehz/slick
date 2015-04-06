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
    assert.is.same({Observable.unwrap(o)}, {1, o})
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

    assert.is.same(a['$observers'], {})
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
    assert.is_not.same(a['$observers'], {})

    Observable.watch(o, nil, function(v, idx)
      assert.is.same({v, idx}, {1, 'a'})
      assert.is.same({coroutine.yield()}, {2, 'a'})
      assert.is.same({coroutine.yield()}, {1, 'b'})
      assert.is.same({coroutine.yield()}, {false, 'a'})
      assert.is.same({coroutine.yield()}, {'test', 'a'})

      v, idx = coroutine.yield()
      assert.is.same({v.b, idx}, {1, 'a'})

      assert.is.same({coroutine.yield()}, {5, 'c'})
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

  describe('chain', function()
    it('should reflect chained [Observable]', function()
      local o1 = Observable.new({a = 1})
      local o2 = Observable.new()
      local o3 = Observable.new({b = 'test1', c = {d = false}})
      local o4 = Observable.new({e = 'test2', f = {g = 'test3'}})
      local o5 = Observable.new(5)

      assert.is.equal(o1.a, 1)
      Observable.chain(Observable.index(o1, 'a'), o2)
      assert.is.equal(o1.a, nil)

      o1.a = 3
      assert.is.equal(o1.a, 3)
      assert.is.equal(Observable.unwrap(o2), 3)
      Observable.set(o2, 4)
      assert.is.equal(Observable.unwrap(o2), 4)
      assert.is.equal(o1.a, 4)

      Observable.chain(o2, o3)
      assert.is.equal(o1.a.b, o2.b, o3.b, 'test1')
      assert.is.equal(o1.a.c.d, o2.c.d, o3.c.d, false)

      Observable.chain(Observable.index(o3.c, 'd'), o4)
      assert.is.equal(o1.a.c.d.e, o2.c.d.e, 'test2')
      assert.is.equal(o1.a.c.d.f.g, o2.c.d.f.g, 'test3')
      o4.e = 10
      o4.f.g = 11
      assert.is.equal(o1.a.c.d.e, o2.c.d.e, 10)
      assert.is.equal(o1.a.c.d.f.g, o2.c.d.f.g, 11)
      o3.c.d.e = 12
      o3.c.d.f.g = 13
      assert.is.equal(o1.a.c.d.e, o2.c.d.e, 12)
      assert.is.equal(o1.a.c.d.f.g, o2.c.d.f.g, 13)
      o3.c.d = 5
      assert.is.equal(Observable.unwrap(o4), 5)
      Observable.set(o4, 6)
      assert.is.equal(o1.a.c.d, o2.c.d, 6)

      Observable.chain(Observable.index(o3.c, 'd'), o5)
      assert.is.equal(o1.a.c.d, o2.c.d, 5)
      Observable.set(o5, 7)
      assert.is.equal(o1.a.c.d, o2.c.d, 7)

      Observable.chain(o2, o5)
      assert.is.equal(o1.a, Observable.unwrap(o2), 7)
      Observable.set(o5, 8)
      assert.is.equal(o1.a, Observable.unwrap(o2), 8)
      o1.a = 9
      assert.is.equal(o1.a, Observable.unwrap(o2), 9)
    end)

    it('should reflect chained [Observable] chains', function()
      local a1 = Observable.new({a = false})
      local a2 = Observable.new()
      local a3 = Observable.new({b = {c = false}})

      local b1 = Observable.new({a = 1})
      local b2 = Observable.new()
      local b3 = Observable.new({b = {c = 2}})

      local c1 = Observable.new()
      local c2 = Observable.new('test')

      Observable.chain(Observable.index(a1, 'a'), a2)
      Observable.chain(a2, a3)

      Observable.chain(Observable.index(b1, 'a'), b2)
      Observable.chain(b2, b3)

      Observable.chain(c1, c2)

      a1.a = b1
      assert.is.equal(
        a1.a.a.b.c, a2.a.b.c, a3.a.b.c,
        b1.a.b.c, b2.b.c, b3.b.c, 2)

      b1.a.b.c = c1
      assert.is.equal(a1.a.a.b.c, 'test')
      Observable.set(c2, false)
      assert.is.equal(a1.a.a.b.c, false)

      a1.a.a.b.c = 3
      assert.is.equal(
        a1.a.a.b.c, a2.a.b.c, a3.a.b.c,
        b1.a.b.c, b2.b.c, b3.b.c, 3)

      b3.b.c = 4
      assert.is.equal(
        a1.a.a.b.c, a2.a.b.c, a3.a.b.c,
        b1.a.b.c, b2.b.c, b3.b.c, 4)

      a1.a = 5
      assert.is.equal(a1.a, Observable.unwrap(a2), Observable.unwrap(a3), 5)

      a1.a = b1
      assert.is.equal(
        a1.a.a.b.c, a2.a.b.c, a3.a.b.c,
        b1.a.b.c, b2.b.c, b3.b.c, 4)

      a1.a = b2
      assert.is.equal(
        a1.a.b.c, a2.b.c, a3.b.c,
        b1.a.b.c, b2.b.c, b3.b.c, 4)
      a1.a.b.c = 5
      assert.is.equal(
        a1.a.b.c, a2.b.c, a3.b.c,
        b1.a.b.c, b2.b.c, b3.b.c, 5)

      a1.a = b3
      assert.is.equal(
        a1.a.b.c, a2.b.c, a3.b.c,
        b1.a.b.c, b2.b.c, b3.b.c, 5)
      a1.a.b.c = 6
      assert.is.equal(
        a1.a.b.c, a2.b.c, a3.b.c,
        b1.a.b.c, b2.b.c, b3.b.c, 6)
    end)

    it('should get change notifications', function()
      local done = {false, false, false, false, false}
      local o1 = Observable.new({a = 1})
      local o2 = Observable.new()
      local o3 = Observable.new()
      local o4 = Observable.new({a = 1})

      Observable.chain(Observable.index(o1, 'a'), o2)
      Observable.chain(o2, o3)
      Observable.chain(Observable.index(o4, 'a'), o3)

      Observable.watch(o1, 'a', function(v)
        assert.is.equal(v, 1)
        assert.is.equal(coroutine.yield(), 2)
        assert.is.equal(coroutine.yield(), 3)
        assert.is.equal(coroutine.yield(), false)
        assert.is.equal(coroutine.yield(), 'test')
        assert.is.equal(coroutine.yield().b, 1)
        assert.is.equal(coroutine.yield().b, 2)
        done[1] = true
      end, nil, true)

      Observable.watch(o1, nil, function(v, idx)
        assert.is.same({v, idx}, {1, 'a'})
        assert.is.same({coroutine.yield()}, {2, 'a'})
        assert.is.same({coroutine.yield()}, {1, 'b'})
        assert.is.same({coroutine.yield()}, {false, 'a'})
        assert.is.same({coroutine.yield()}, {'test', 'a'})

        v, idx = coroutine.yield()
        assert.is.same({v.b, idx}, {1, 'a'})

        assert.is.same({coroutine.yield()}, {5, 'c'})
        done[2] = true
      end, nil, true)

      Observable.watch(o2, nil, function(v)
        assert.is.equal(v, 1)
        assert.is.equal(coroutine.yield(), 2)
        assert.is.equal(coroutine.yield(), 3)
        assert.is.equal(coroutine.yield(), false)
        assert.is.equal(coroutine.yield(), 'test')
        assert.is.equal(coroutine.yield().b, 1)
        assert.is.equal(coroutine.yield().b, 2)
        done[3] = true
      end, nil, true)

      Observable.watch(o3, nil, function(v)
        assert.is.equal(v, 1)
        assert.is.equal(coroutine.yield(), 2)
        assert.is.equal(coroutine.yield(), 3)
        assert.is.equal(coroutine.yield(), false)
        assert.is.equal(coroutine.yield(), 'test')
        assert.is.equal(coroutine.yield().b, 1)
        assert.is.equal(coroutine.yield().b, 2)
        done[4] = true
      end, nil, true)

      Observable.watch(o4, 'a', function(v)
        assert.is.equal(v, 1)
        assert.is.equal(coroutine.yield(), 2)
        assert.is.equal(coroutine.yield(), 3)
        assert.is.equal(coroutine.yield(), false)
        assert.is.equal(coroutine.yield(), 'test')
        assert.is.equal(coroutine.yield().b, 1)
        assert.is.equal(coroutine.yield().b, 2)
        done[5] = true
      end, nil, true)

      o1.a = 1
      assert.is.equal(Observable.unwrap(o3), 1)
      o1.a = 2
      assert.is.equal(Observable.unwrap(o3), 2)
      Observable.set(o2, 3)
      assert.is.equal(Observable.unwrap(o3), 3)
      o1.b = 1
      o1.a = false
      assert.is.equal(Observable.unwrap(o3), false)
      o1.a = 'test'
      assert.is.equal(Observable.unwrap(o3), 'test')
      o1.a = {b = 1}
      assert.is.equal(Observable.unwrap(o3).b, 1)
      Observable.set(o3, {b = 2})
      assert.is.equal(Observable.unwrap(o3).b, 2)
      o1.c = 5

      assert.is.same(done, {true, true, true, true, true})
    end)
  end)
end)
