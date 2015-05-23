local java = {}
local import_cache = {}


local object = {
  __index = function(self, name)
    local cls = rawget(self, '_class')

    -- Fields
    if cls._fields[name] then
    end

    -- Methods
    if cls._methods[name] then
      return java.method(cls, name)
    end
  end
}


local class = {
  __call = function(self, ...)
    return setmetatable({
      _class = self,
      _ref = _internal.new(self._constructors, ...)
    }, object)
  end
}


function java.import(name)
  name = name:gsub('%.', '/')
  if import_cache[name] then
    return import_cache[name]
  end

  local cls = _internal.import(name)
  cls._name = name
  cls._invoke = {}

  import_cache[name] = cls
  return setmetatable(cls, class)
end


function java.reference(ref, cls)
  if type(cls) == 'string' then
    cls = java.import(cls)
  end
  return setmetatable({
    _class = cls,
    _ref = ref
  }, object)
end


function java.method(cls, name)
  if not cls._invoke[name] then
    cls._invoke[name] = function(self, ...)
      return _internal.invoke(
        self._class._methods[name], name, self._ref, ...)
    end
  end
  return cls._invoke[name]
end


return java
