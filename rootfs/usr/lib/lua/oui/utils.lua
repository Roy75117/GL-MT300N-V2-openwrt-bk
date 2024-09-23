local core = require "oui.utils.utils"
local fs = require "oui.fs"
local uci = require "uci"

local M = {}

setmetatable(M, {
    __index = core
})

-- The available formats are:
-- "n": reads a numeral and returns it as a float or an integer, following the lexical conventions of Lua.
-- "a": reads the whole file. This is the default format.
-- "l": reads the next line skipping the end of line.
-- "L": reads the next line keeping the end-of-line character (if present).
-- number: reads a string with up to this number of bytes. If number is zero, it reads nothing and returns an empty string.
-- Return nil if the file open failed
M.readfile = function(name, format)
    local f = io.open(name, "r")
    if not f then return nil end

    -- Compatible with the version below 5.3
    if type(format) == "string" and format:sub(1, 1) ~= "*" then format = "*" .. format end

    local data

    if format == "*L" and tonumber(_VERSION:match("%d.%d")) < 5.2 then
        data = f:read("*l")
        if data then data = data .. "\n" end
    else
        data = f:read(format or "*a")
    end

    f:close()
    return data or ""
end

M.writefile = function (name, data, append)
    local f = io.open(name, append and "a" or "w")
    if not f then return nil end
    f:write(data)
    f:close()
    return true
end

M.generate_id = function(n)
    local t = {
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
    }

    local f = io.open('/dev/urandom')

    assert(f)

    local s = {}
    for _ = 1, n do
        local i = f:read(1)
        s[#s + 1] = t[i:byte() % #t + 1]
    end

    f:close()

    return table.concat(s)
end

local function check_net(ip, port)
    local sock = ngx.socket.tcp()
    sock:settimeout(1000)
    local ok = sock:connect(ip, port)
    sock:close()
    return ok
end

M.get_net_status = function()
    local port = 53
    local c = uci.cursor()
    local track_ips = c:get("glconfig", "general", "track_ip")

    for _, ip in ipairs(track_ips) do
        if check_net(ip, port) then return true end
    end

    return false
end

--[[
    local utils = require 'oui.utils'

    local pids =  utils.pidof('nginx')

    for _, pid in ipairs(pids) do
        print(pid)
    end
--]]
M.pidof = function(name)
    local pids = {}

    for pid in fs.dir("/proc") do
        if pid:match("%d+") == pid then
            local comm = M.readfile("/proc/" .. pid .. "/comm", "l")
            if comm == name then
                pids[#pids + 1] = tonumber(pid)
            end
        end
    end

    return pids
end

return M
