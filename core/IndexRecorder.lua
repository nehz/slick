local IndexRecorder = {}


function IndexRecorder.new(type)
  return setmetatable({type = type}, IndexRecorder)
end


function IndexRecorder:__index(name)
  if rawget(self, 1) then
    table.insert(self, name)
    return self
  end
  local info = {type = self.type, args = {}}
  return setmetatable({['$info'] = info, name}, IndexRecorder)
end


function IndexRecorder:__call(...)
  assert(rawget(self, 1))
  local args = table.pack(...)
  if self == args[1] then
    self['$info'].args = table.pack(table.unpack(args, 2, args.n))
    self['$info'].id = table.remove(self)
  else
    self['$info'].args = args
  end
  return self
end


function IndexRecorder:__mod(value)
  assert(rawget(self, 1))
  self['$info'].init = value
  return self
end
IndexRecorder.__bxor = IndexRecorder.__mod


function IndexRecorder:__tostring()
  if #self > 0 then
    return string.format('IndexRecorder(%s.%s)',
      self['$info'].type, table.concat(self, '.'))
  else
    return string.format('IndexRecorder(%s)', self.type)
  end
end


function IndexRecorder.info(i)
  assert(getmetatable(i) == IndexRecorder)
  assert(rawget(i, 1))
  return i['$info']
end


function IndexRecorder.value(i)
  assert(getmetatable(i) == IndexRecorder)
  if #i == 0 then
    return i.type
  else
    return i['$info'].type .. '.' .. table.concat(i, '.')
  end
end


return IndexRecorder
