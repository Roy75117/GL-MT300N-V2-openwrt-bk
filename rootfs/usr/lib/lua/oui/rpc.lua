local utils = require "oui.utils"
local cjson = require "cjson"
local db = require "oui.db"
local fs = require "oui.fs"
local uci = require "uci"
local ubus = require "oui.ubus"

local M = {
    ERROR_CODE_NONE = 0,
    ERROR_CODE_PARSE_ERROR = -32700,
    ERROR_CODE_INVALID_REQUEST = -32600,
    ERROR_CODE_METHOD_NOT_FOUND = -32601,
    ERROR_CODE_INVALID_PARAMS = -32602,
    ERROR_CODE_INTERNAL_ERROR = -32603,

    -- Custom error code
    ERROR_CODE_ACCESS = -32000,
    ERROR_CODE_NOT_FOUND = -32001,
    ERROR_CODE_SESSION_OVER_LIMIT = -32002,
    ERROR_CODE_LOGIN_FAIL_OVER_LIMIT = -32003
}

local rpc_error_message = {
    [M.ERROR_CODE_PARSE_ERROR] = "Parse error",
    [M.ERROR_CODE_INVALID_REQUEST] = "Invalid Request",
    [M.ERROR_CODE_METHOD_NOT_FOUND] = "Method not found",
    [M.ERROR_CODE_INVALID_PARAMS] = "Invalid params",
    [M.ERROR_CODE_INTERNAL_ERROR] = "Internal error",
    [M.ERROR_CODE_ACCESS] = "Access denied",
    [M.ERROR_CODE_NOT_FOUND] = "Not found",
    [M.ERROR_CODE_SESSION_OVER_LIMIT] = "Login session's number over limit",
    [M.ERROR_CODE_LOGIN_FAIL_OVER_LIMIT] = "Login fail number over limit"
}

local objects = {}
local no_auth_methods

M.error_response = function(id, code, data)
    return {
        jsonrpc = "2.0",
        id = id or cjson.null,
        error = {
            code = code,
            message = rpc_error_message[code] and rpc_error_message[code] or "Unknown",
            data = data
        }
    }
end

M.result_response = function(id, result_obj)
    return {
        jsonrpc = "2.0",
        id = id or cjson.null,
        result = result_obj or cjson.null
    }
end

M.session = function()
    local session = ubus.call("gl-session", "session", { sid = ngx.ctx.sid })

    local __oui_session = {
        is_local = ngx.var.remote_addr == "127.0.0.1" or ngx.var.remote_addr == "::1",
        remote_addr = ngx.var.remote_addr,
        remote_port = ngx.var.remote_port
    }

    if not session then return __oui_session end

    utils.update_ngx_session("/tmp/gl_token_" .. ngx.ctx.sid)

    session.remote_addr = ngx.var.remote_addr
    session.remote_port = ngx.var.remote_port

    return session
end

M.access = function(scope, entry, need)
    local headers = ngx.req.get_headers()
    local s = M.session()
    local aclgroup = s.aclgroup

    if s.is_local and headers["glinet"] then
        return true
    end

    -- The admin acl group is always allowed
    if aclgroup == "root" then return true end

    if not aclgroup or aclgroup == "" then return false end

    local perm = db.get_perm(aclgroup, scope, entry)

    if not need then return false end

    if need == "r" then
        return perm:find("[r,w]") ~= nil
    else
        return perm:find(need) ~= nil
    end
end

M.is_no_auth = function(object, method)
    local c = uci.cursor()

    if not no_auth_methods then
        no_auth_methods = {}

        c:foreach("oui-httpd", "no-auth-methods", function(s)
            local ms = {}

            for _, m in ipairs(s.method) do
                ms[m] = true
            end

            no_auth_methods[s.object] = ms
        end)
    end

    if no_auth_methods[object] and no_auth_methods[object][method] then
        return true
    end

    return false
end

local function glc_call(object, method, args)
    ngx.log(ngx.DEBUG, "call C: '", object, ".", method, "'")

    local res = ngx.location.capture("/cgi-bin/glc", {
        method = ngx.HTTP_POST,
        body = cjson.encode({
            object = object,
            method = method,
            args = args or {}
        })
    })

    if res.status ~= ngx.HTTP_OK then return M.ERROR_CODE_INTERNAL_ERROR end

    local body = res.body
    local code = tonumber(body:match("(-?%d+)"))

    if code ~= M.ERROR_CODE_NONE then
        local err_msg = body:match("%d+ (.+)")
        if err_msg then
            ngx.log(ngx.ERR, err_msg)
        end
        return code
    end

    local msg = body:match("%d+ (.*)")

    return cjson.decode(msg)
end

M.call = function(object, method, args)
    ngx.log(ngx.DEBUG, "call: '", object, ".", method, "'")

    if not objects[object] then
        local script = "/usr/lib/oui-httpd/rpc/" .. object
        if not fs.access(script) then
            return glc_call(object, method, args)
        end

        local ok, tb = pcall(dofile, script)
        if not ok then
            ngx.log(ngx.ERR, tb)
            return glc_call(object, method, args)
        end

        if type(tb) == "table" then
            local funs = {}
            for k, v in pairs(tb) do
                if type(v) == "function" then
                    funs[k] = v
                end
            end
            objects[object] = funs
        end
    end

    local fn = objects[object] and objects[object][method]
    if not fn  then
        return glc_call(object, method, args)
    end

    return fn(args)
end

return M
