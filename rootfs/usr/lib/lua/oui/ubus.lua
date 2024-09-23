local ubus = require "ubus"

local M = {}

function M.call(object, method, arg)
    local conn = ubus.connect()
    local r, err = conn:call(object, method, arg or {})
    conn:close()

    if err then
        return r, err
    end

    return r
end

return M
