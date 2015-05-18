require('core.env.strict')
require('core.env.fenv')
require('core.env.table')


_assert = assert
function assert(v, ...)
  if not v then
    local args = table.pack(...)
    error(table.concat(args, ' ', 1, args.n), 2)
  end
  return v
end
