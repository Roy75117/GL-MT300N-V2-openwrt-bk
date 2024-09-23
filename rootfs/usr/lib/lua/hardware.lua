local M = {}

local lfactory = require "lfactory"
local rpc = require "oui.rpc"
local uci = require "uci"
local utils = require "oui.utils"
local ubus = require "oui.ubus"

function M.platform_get_wan_status()
    local model = lfactory.get_model()
    local c = uci.cursor()
    local cmd

    if model == "mt750" or model == "vixmini" or model == "mt300n-v2" or model == "n300" or model == "sf1200" or model == "sft1200" then
        cmd = "swconfig dev switch0 port 0 show | grep link:up"
    elseif model == "ar750s" then
        cmd = "swconfig dev switch0 port 1 show | grep link:up"
    elseif model == "x1200" then
        cmd = "swconfig dev switch0 port 5 show | grep link:up"
    elseif model == "b3000" then
        cmd = "swconfig dev switch1 port 1 show | grep link:up"
    elseif model == "mv1000" or model == "mt1300" then
        cmd = "ethtool wan|grep Link.*yes"
    elseif model == "xe300" or model == "a1300" or model == "b1300" or model == "s1300" or model == "ap1300" or model == "mt6000" then
        cmd = "ethtool eth1|grep Link.*yes"
    else
        cmd = "ethtool eth0|grep Link.*yes"
    end

    local rs_file = assert(io.popen(cmd))
    local ret = rs_file:read() or ""
    rs_file:close()

    local cable_enabled
    local tmp
    if string.len(ret) >5 then
        tmp = c:get("network", "wan", "metric") or ""
        if type(tmp) ~= "string" or tmp:gsub("%s+", "") == "" then
            c:set("network", "wan", "metric", "10")
            c:commit("network")
        end
        cable_enabled = true
    else
        cable_enabled = false
    end



    local wan2lan = c:get("glconfig", "general", "wan2lan") or ""
    if wan2lan == "1" or model == "usb150" then
        cable_enabled = false
    end

    -- macclone usb150
    local macclone = c:get("glconfig", "general", "macclone") or ""
    local macclone_enabled = false
    local session = rpc.session()
    -- local remote_addr, cmd_str, rs_file, mac_lower, remote_mac = ""
    if model == "usb150" then
        local remote_addr = session.remote_addr
        local cmd_str = "ip ne | grep br-lan | grep "..remote_addr.." | awk '{print $5}'"
        local rs_file = assert(io.popen(cmd_str))
        local mac_lower = rs_file:read() or ""
        local remote_mac = string.upper(mac_lower)
        rs_file:close()

        local sta_macaddr = c:get("wireless", "sta", "macaddr") or ""
        if macclone == "1" or sta_macaddr == remote_mac then
            macclone_enabled = true
        end
    else
        macclone_enabled = macclone == "1"
    end
    return  { cable_enabled = cable_enabled , macclone_enabled = macclone_enabled }
end

function M.platform_get_secondwan_status()
    local c = uci.cursor()

    local ifname = lfactory.get_secondwan_port()
    local cable_enabled = utils.readfile('sys/class/net/' .. ifname .. '/carrier', '*n') == 1

    local lan2wan = c:get("glconfig", "general", "lan2wan") == "1"
    if lan2wan == false then
        cable_enabled = false
    end

    local macclone_enabled = c:get("glconfig", "general", "macclone") == "1"

    return  { cable_enabled = cable_enabled , macclone_enabled = macclone_enabled }
end

function M.platform_support_secondwan()
    local model = lfactory.get_model()
    if model == "xe3000" or model == "mt6000" or model == "x3000" or model == "b3000" then
        return true
    end
    return false
end

function M.platform_switch_restart()
    local model = lfactory.get_model()

    if model == "ar150" or model == "mifi" or model == "ar750"
      or model == "ar300m" or model == "x750" or model == "e750"
      or model == "x300b" or model == "xe300" or model == "s200"
      or model == "ar750s" then
        ngx.pipe.spawn("swconfig dev switch0 set reset")
    elseif model == "a1300" or model == "b1300" or model == "s1300" or model == "ap1300" then
        ngx.pipe.spawn("swconfig dev switch0 set linkdown 1;sleep 1;swconfig dev switch0 set linkdown 0")
    elseif model == "mt300n-v2" then
        ngx.pipe.spawn("swconfig dev switch0 port 1 set disable 1;swconfig dev switch0 set apply 1;sleep 1;swconfig dev switch0 port 1 set disable 0;swconfig dev switch0 set apply 1")
    elseif model == "sft1200" or model == "sf1200" then
        ngx.pipe.spawn({"/etc/init.d/network", "restart"})
    end
end

function M.platform_get_time_info()
    local model = lfactory.get_model()

    if model == "ar150" or model == "mifi" or model == "x300b"
      or model == "s200" or model == "a1300" then
        return  { upgrade = 240 , reboot = 120, init = 10 }
    elseif model == "xe300" or model == "x750" or model == "e750"
      or model == "ar750" or model == "ar300m" or model == "sft1200"
      or model == "b1300" or model == "ar750s" or model == "mt1300"
      or model == "mt300n-v2" then
        return  { upgrade = 240 , reboot = 180, init = 10 }
    else
        return  { upgrade = 120 , reboot = 60, init = 3 }
    end
end


function M.platform_telething_whether_removing_usb0()
    local model = lfactory.get_model()
    local usb

    if model == "mv1000" then
	    usb = "usb0"
    elseif model == "x3000" then
	    usb = "rm500u_5gnet"
    end

    return usb
end

function M.platform_factory_reset_mcu()
    local model = lfactory.get_model()

    if model == "e750" then
	ubus.call("mcu", "system_reft", { system = 'reft' })
        ngx.pipe.spawn("sleep 2;/etc/init.d/mcu stop")
    end
end

function M.platform_older_models_add_delay()
    local model = lfactory.get_model()

    if model == "ar150" or model == "mifi" or model == "ar750"
      or model == "ar300m" or model == "x750" or model == "e750"
      or model == "x300b" or model == "xe300" or model == "s200"
      or model == "sft1200" or model == "b1300" or model == "a1300"
      or model == "ar750s"  or model == "mt1300" or model == "mt300n-v2" then
        ngx.sleep(8)
    end
end

return M
