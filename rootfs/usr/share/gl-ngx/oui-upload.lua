local upload = require "resty.upload"
local fs = require "oui.fs"
local ubus = require "oui.ubus"
local rpc = require "oui.rpc"

local form, err = upload:new(4096)
if not form then
    ngx.log(ngx.ERR, "failed to new upload: ", err)
    ngx.exit(500)
end

form:set_timeout(1000)

local name
local contents = {}
local authed = false
local path
local f

local function path_is_allowed(to)
    if to:match("%.%.") or to:match("~") then
        return false
    end

    for conf in fs.dir("/usr/share/gl-upload.d") do
        if conf ~= "." and conf ~= ".." then
            for line in io.lines("/usr/share/gl-upload.d/" .. conf) do
                if to:match('^' .. line) then
                    return true
                end
            end
        end
    end

    return false
end

while true do
    local typ, res, err = form:read()
    if not typ then
        ngx.log(ngx.ERR, "failed to read: ", err)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if typ == "header" and #res > 1 and (res[1] == "Content-Disposition" or res[1] == "content-disposition") then
        name = res[2]:match('name="(%w+)"')
        if not name then
            ngx.log(ngx.ERR, "invalid header: ", table.concat(res, ";"))
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
        contents[name] = {}
    elseif typ == "body" then
        if name == "file" then
            local is_local = ngx.var.remote_addr == "127.0.0.1" or ngx.var.remote_addr == "::1"
            if not authed and not is_local then
                ngx.exit(ngx.HTTP_UNAUTHORIZED)
            end

            if not contents["path"] then
                ngx.log(ngx.ERR, "Not found path")
                ngx.exit(ngx.HTTP_HTTP_FORBIDDEN)
            end

            if authed then
                if not rpc.access("upload", contents["path"]) then
                    ngx.exit(ngx.HTTP_FORBIDDEN)
                end
            end

            if not f then
                path = contents["path"]
                f, err = io.open(path, "w+")
                if not f then
                    ngx.log(ngx.ERR, "open ", contents["path"], " fail: ", err)
                    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
                end
            end

            local size = tonumber(contents["size"])
            local c = size / (1024 * 1024)
            if path:find('ovpn') and c > 10 then
                ngx.log(ngx.ERR, "the uploaded file is too large, please upload a file within 10MB.")
                ngx.exit(413)
            end

            local _, a = fs.statvfs(fs.dirname(contents["path"]))
            if a < 1024 * 1024 then
                f:close()
                os.remove(path)
                ngx.log(ngx.ERR, "No enough space left on device")
                ngx.exit(413)
            end

            f:write(res)
        else
            local content = contents[name]
            content[#content + 1] = res
        end
    elseif typ == "part_end" then
        contents[name] = table.concat(contents[name])
        if name == "sid" then
            local sid = contents[name]
            local session = ubus.call("gl-session", "session", { sid = sid })
            if session then
                ngx.ctx.sid = sid
                authed = true
            end
        elseif name == "path" then
            if not path_is_allowed(contents[name]) then
                ngx.log(ngx.ERR, "Not allowed path")
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end
        elseif name == "file" then
            if f then
                f:close()
                break
            end
        end
    end

    if typ == "eof" then break end
end

if not f then ngx.exit(ngx.HTTP_FORBIDDEN) end

