#!/usr/bin/env eco

local time = require 'eco.time'
local http = require 'eco.http'
local file = require 'eco.file'
local sys = require 'eco.sys'
local log = require "eco.log"
local uci = require "uci"
local ubus = require 'eco.ubus'
local cjson = require "cjson"

local Signal = {}
Signal.__index = Signal

local signal = {}
local signal_data = {}
local cloud_timer
local ubus_conn

function Signal:load_config()
    local c = uci.cursor()

    log.info("load config...")

    c:foreach("glmodem", "signal", function(s)
        self.signal_capture_interval = tonumber(s.signal_capture_interval or 10)
        self.signal_capture_cycle = tonumber(s.signal_capture_cycle or 1800)
        --self.signal_cloud_cycle = tonumber(s.signal_cloud_cycle or 300)
        --self.signal_web_cycle = tonumber(s.signal_web_cycle or 1800)
        self.enable = tonumber(s.enable or 0)
    end)

end

local function get_nginx_port()
    local conf = file.readfile('/etc/nginx/conf.d/gl.conf') or ''
    local port = conf:match('listen (%d+);')
    return port and tonumber(port)
end

local function call_rpc(mod, func, params)
    local port = get_nginx_port()
    if not port then
        log.err('get nginx port fail')
        return nil
    end

    local url = 'http://127.0.0.1/rpc'
    if port ~= 80 then
        url = string.format('http://127.0.0.1:%d/rpc', port)
    end

    local req = {
        method = 'call',
        params = {'', mod, func, params}
    }

    local resp, err = http.request({ url = url, headers = { glinet = 1 } }, cjson.encode(req))
    if not resp then
        log.err('call', mod .. '.' .. func, 'fail:', err)
        return nil
    end

    if resp.code ~= 200 then
        log.err('call', mod .. '.' .. func, 'fail with http code:', resp.code)
        return nil
    end

    local body, err = resp.read_body(-1)
    if not body then
        log.err('read body fail:', err)
        return nil
    end

    if body == '' then
        log.err('no body response')
        return nil
    end

    return cjson.decode(body)
end

function Signal:collects()
    local total = self.signal_capture_cycle / self.signal_capture_interval
    total = total + 1

    log.info("start collecting sim signals...")
    time.at(self.signal_capture_interval, function(tmr)
        local data = call_rpc('modem', 'get_sim_signal')
        log.debug(cjson.encode(data))
        if type(data) == "table" then
            local sig = data.result.signal or {}
            sig.timestamp = os.time();
            sig.slot = data.result.slot
            if #signal_data == total then
                table.remove(signal_data)
            end
            table.insert(signal_data,1,sig)
            --signal_data[#signal_data + 1] = sig
        end
        log.debug(cjson.encode(signal_data))
        tmr:set(self.signal_capture_interval)
    end)
end

function Signal:get_signals(msg)
    local num
    if msg.time then
        num = math.floor(msg.time / self.signal_capture_interval)
    else
        num = 180
    end

    local s = {}

    log.debug(cjson.encode(signal_data))

    num = num + 1
    local signal_tmp = signal_data
    if num >= #signal_tmp then
        return signal_tmp
    else
        for _,v in pairs(signal_tmp) do
            s[#s + 1] = v
            if #s == num then
                break
            end
        end
        return s
    end
end

function Signal:upload_cloud_signals(msg)
    local c = uci.cursor()
    local cloud = {}
    if cloud_timer then
        cloud_timer:cancel()
    end

    if msg and msg.action == "stop" then
        return 0
    end

    cloud.time = tonumber(c:get("glmodem","signal", "signal_cloud_cycle") or 300)
    cloud_timer = time.at(10.0, function(cloud_timer)
        local s = signal:get_signals(cloud)
        --log.info(cjson.encode(s))
        ubus.call('gl-cloud', 'notify', {
            type = 'modem/batch_signal',
            data = {
                signals = s
            }
        })
        cloud_timer:set(cloud.time)
    end)

    return 0
end

function Signal:cloud_init()
        local c = uci.cursor()
        local enable = c:get('gl-cloud', '@cloud[0]', 'enable')
        if enable == "1" then
            signal:upload_cloud_signals()
        end

        ubus_conn:listen('ubus.object.add', function(ev, msg)
            local object = msg.path
            if object == "gl-cloud" then
                signal:upload_cloud_signals()
            end
        end)
        ubus_conn:listen('ubus.object.remove', function(ev, msg)
            local object = msg.path
            if object == "gl-cloud" then
                local cloud = {}
                cloud.action = "stop"
                signal:upload_cloud_signals(cloud)
            end
        end)
end

local function Signal_handle()

    setmetatable(signal, Signal)

    signal:load_config()

    if signal.enable then
        signal:collects()
        signal:cloud_init()
    end
end

local function modem_manager()

    Signal_handle()
end

local function ubus_init()
    ubus_conn = ubus.connect()
    if not ubus_conn then
        error("Failed to connect to ubus")
    end

    --ubus.ubus_conn = ubus_conn

    --ubus.reply = function(req, msg)
        --return ubus_conn:reply(req, msg or {})
    --end

    ubus_conn:add(
        'modem.signal', {
            get_signals = {
                function(req,msg)
                    local s = signal:get_signals(msg)
                    ubus_conn:reply(req, {signals = s})
                end, { time = ubus.INT32 }
            },
            upload_cloud_signals = {
                function(req,msg)
                    local result = signal:upload_cloud_signals()
                    ubus_conn:reply(req, {code = result})
                end, { action = ubus.STRING }
            }
        }
    )
end

sys.signal(sys.SIGINT, function()
    log.info('\nGot SIGINT, now quit')
    eco.unloop()
end)

sys.signal(sys.SIGTERM, function()
    log.info('\nGot SIGTERM, now quit')
    eco.unloop()
end)

local function main()
    eco.run(ubus_init)

    modem_manager()
end

main()
