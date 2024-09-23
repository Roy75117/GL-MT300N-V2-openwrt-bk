#!/usr/bin/lua

local lfactory = require "lfactory"
local uci = require "uci"
local ubus = require "oui.ubus"
local fs = require "oui.fs"
local utils = require "oui.utils"

local network = {}
local c = uci.cursor()

local mode_str = c:get("glconfig", "general", "mode") or "router"
local mode = 5

if mode_str == "router"  then
	mode = 0
elseif mode_str == "wds" then
	mode = 1
elseif mode_str == "relay" then
	mode = 2
elseif mode_str == "mesh" then
	mode = 3
elseif mode_str == "ap" then
	mode = 4
end

c:foreach("mwan3", "interface", function(s)
	local name = s[".name"]
	if mode == 4 and name == "wan" then
		name = "lan"
	elseif mode == 1 and name == "wwan" then
		name = "lan"
	end

	local up = (ubus.call("network.interface."..name, "status") or {}).up or false
	local mwan3track_file = "/var/run/mwan3track/" .. name .. "/STATUS"
	local online = up
	local mwan3_enable = c:get("mwan3", name, "enabled") == "1"
	if mwan3_enable then
		online = up and fs.access(mwan3track_file) and utils.readfile(mwan3track_file, "*l") == "online" or false
	end
	if name == "lan" and up == true then
		online = true
	end

	if online then
		online = "online"
	else
		online = "offline"
	end

	network[#network + 1] = {
		interface = s[".name"],
		online = online,
		up = up,
		print(name),
		print(up),
		print(online),
	}
end)

local modem_bus = lfactory.get_build_modem_port() or ""
if type(modem_bus) == "string" and modem_bus:gsub("%s+", "") ~= "" then
	local name = "modem_" .. string.gsub(modem_bus, "%D", "_")
	local mwan3track_file = "/var/run/mwan3track/" .. name .. "/STATUS"
	local up = (ubus.call("network.interface."..name, "status") or {}).up or false
	local online = up and fs.access(mwan3track_file) and utils.readfile(mwan3track_file, "*l") == "online" or false

	if online then
		online = "online"
	else
		online = "offline"
	end

	network[#network + 1] = {
		interface = name,
		online = online,
		up = up,
		print(name),
		print(up),
		print(online),
	}
end
