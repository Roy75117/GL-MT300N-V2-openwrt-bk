local utils = require 'oui.utils'
local uci = require "uci"

local c = uci.cursor()
local redirect_https = c:get("oui-httpd", "main", "redirect_https") == "1"

local function get_ssl_port()
    local text = utils.readfile('/etc/nginx/conf.d/gl.conf')
    return text:match('listen (%d+) ssl;')
end

if redirect_https and ngx.var.scheme == "http" then
    local host = ngx.var.host
    local ssl_port = get_ssl_port()
    if ssl_port ~= '443' then
        host = host .. ':' .. ssl_port
    end
    return ngx.redirect("https://" .. host .. ngx.var.request_uri)
end
