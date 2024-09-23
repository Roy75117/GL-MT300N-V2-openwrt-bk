#!/usr/bin/lua

local lfactory = require "lfactory"

local build_in_modem = lfactory.get_build_modem_port() or ""
print(build_in_modem)