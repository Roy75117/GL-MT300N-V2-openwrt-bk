#!/bin/sh
. /lib/functions.sh

handle_modem()
{
	if [ "$(echo $1 | grep -q 'modem';echo $?)" = "0" ]; then
		config_get_bool disabled "$1" 'disabled'
		config_get node "$1" 'node'
		config_get device "$1" 'device'

		[ "$(basename $2 | grep -q $node;echo $?)" = "0" ] || {
			echo "$(basename $2) not true node"
			return
		}
		devpath="$(find  /sys/devices/ -name "$node" 2>/dev/null)"
		devname="$(find "$devpath" -name  "cdc-wdm*" 2>/dev/null)"
		devname="$(basename "$devname")"
		if [ -z "$devpath" ];then
	 		dev_dir="usbmisc"
	 		devname="$(basename "$device")"
	 		[ "$(echo $device | grep -q 'ttyUSB';echo $?)" = "0" ] && dev_dir="tty"
	   		devpath="$(readlink -f /sys/class/$dev_dir/$devname/device/)"
		fi

		recover_flag=0
		[ "$disabled" = "0" ] && recover_flag=1
		[ -z "$(uci -q get glmodem.$1)" ] && uci set glmodem.$1="interface"
		uci set glmodem.$1.enable_recover="$recover_flag"
		uci commit glmodem

		if [ ! -e "$devpath" ]; then
			echo "device down"
			[ "$(uci -q get network.$1.disabled)" = "0" ] && {
				uci set network.$1.disabled="1"
				uci commit network
				/etc/init.d/network reload
			}
		fi
	fi
}

recover_modem()	
{
	node=$(uci -q get network.$1.node)
	[ "$(basename $2 | grep -q $node;echo $?)" = "0" ] || {
		echo "$(basename $2) not true node"
		return
	}
	config_get_bool enable_recover "$1" 'enable_recover' 0
	if [ "$(uci -q get network.$1.disabled)" = "1" -a "$enable_recover" = "1" ]; then
		uci set network.$1.disabled="0"
		uci commit network
		sleep 5
		/etc/init.d/network reload
	fi
}

get_modem_type()
{
	local flag=2
	local bus="$1"
	if [ -e "/proc/gl-hw-info/build-in-modem" ]; then
		local build_in="$(cat /proc/gl-hw-info/build-in-modem)"
		if [ "$(echo $build_in | grep -q ',';echo $?)" = "0" ]; then
			local build_in_array="${build_in/,/ }"
			for modem in $build_in_array
			do
			    [ "$bus" = "$modem" ] && flag=0
			done
		else
			[ "$1" = "$build_in" ] && flag=0
		fi
	fi
	if [ -e "/proc/gl-hw-info/usb-port" ]; then
		local usb_port="$(cat /proc/gl-hw-info/usb-port)"
		if [ "$(echo $usb_port | grep -q ',';echo $?)" = "0" ]; then
			local usb_port_array="${usb_port/,/ }"
			for modem in $usb_port_array
			do
			    [ "$bus" = "$modem" -a "$flag" = "2" ] && flag=1
			done
		else
			[ "$bus" = "$usb_port" -a "$flag" = "2" ] && flag=1
		fi
	fi
	echo $flag
}

check_modem_config()
{
	[ "$(echo $1 | grep -q 'modem';echo $?)" = "0" ] || return
	config_get node "$1" 'node'
	modem_type="2"
	bus="$(echo $node | cut -d ':' -f1)"
	modem_type="$(get_modem_type $bus)"

	devpath="$(find  /sys/devices/ -name "$node" 2>/dev/null)"
	if [ -z "$devpath" -a "$modem_type" = "1" ]; then
		[ -z "$(uci -q get network.$1)" ] || {
			uci -q delete network.$1
			uci commit network
		}
	fi
}

if [ "$ACTION" = "remove" -a "$DEVTYPE" = "usb_interface" ]; then
	config_load network
	config_foreach handle_modem interface "$DEVICENAME"
fi

if [ "$ACTION" = "add" -a "$DEVTYPE" = "usb_interface" ]; then
	config_load network
	config_foreach check_modem_config interface
	config_load glmodem
	config_foreach recover_modem interface "$DEVICENAME"
fi