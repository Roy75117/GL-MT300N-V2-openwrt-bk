#!/bin/sh

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

proto_qcm_init_config() {
	available=1
	no_device=1
	proto_config_add_string "device:device"
	proto_config_add_string "ifname"
	proto_config_add_string "apn"
	proto_config_add_string "pincode"
	proto_config_add_string "auth"
	proto_config_add_string "username"
	proto_config_add_string "password"
	proto_config_add_string "node"
	proto_config_add_string "date"
	proto_config_add_int "mtu"
	proto_config_add_int "apn_use"
	proto_config_add_defaults
}

proto_qcm_setup() {
	local interface="$1"
	local devpath=""
	local devname=""

	local device ifname  apn pincode ifname auth username password  node $PROTO_DEFAULT_OPTIONS mtu band_enable band_list apn_use date
	json_get_vars device ifname apn pincode auth username password  node $PROTO_DEFAULT_OPTIONS mtu	band_enable band_list apn_use date
	local ipv6=`uci get glipv6.globals.enabled 2>/dev/null`

	if [ -f "/proc/gl-hw-info/build-in-modem" ];then
		. /lib/functions/modem.sh
		[ "$apn_use" = "" ] && {
			apn_use=`check_apn`
			if [ "$apn_use" = "0" ];then
				echo "The apn does not get."
				sleep 1
				return 1
			elif [ "$apn_use" = "-1" ];then
				echo "SIM not ready"
			fi
		}
		modem_AT_set_roaming
		modem_AT_set_band
		modem_AT_lock_cell_tower
		modem_AT_set_apn
	fi

	# fix_tmobile_dial

	case $auth in
	"PAP") auth=1 ;;
	"CHAP") auth=2 ;;
	"PAP or CHAP") auth=3 ;;
	"PAP/CHAP") auth=3 ;;
	*) auth=0 ;;
	esac

	if [ -n "$node" ];then
		devpath="$(find  /sys/devices/ -name "$node" 2>/dev/null)"
		devname="$(find "$devpath" -name  "cdc-wdm*" 2>/dev/null)"
		devname="$(basename "$devname")"
	else
 		devname="$(basename "$device")"

		if [ ${devname/mhi//} == $devname ];then
			devpath="$(readlink -f /sys/class/usbmisc/$devname/device/)"
			bus="$(basename "$devpath"|cut -d ':' -f 1)"
		else
			devpath="$(readlink -f /sys/class/net/rmnet_mhi0/device)"
			bus="$(basename $(dirname "$devpath"))"
		fi
	fi
	
	if [ -n "$node" ];then
		#fix config
		[ "$devname" = "$(basename "$device")" ] || {
			[ -n "$devname" ] && uci set network."$interface".device="/dev/${devname}" && uci commit
		}
	fi

	device="$(readlink -f $device)"
	[ -c "$device" ] || {
		echo "The specified control device does not exist"
		proto_notify_error "$interface" NO_DEVICE
		proto_set_available "$interface" 0
		return 1
	}

	ifname="$( ls "$devpath"/net )"
	dataformat="$(uqmi -t 3000 -s -d "$device" --wda-get-data-format)"
	if [ "$dataformat" = '"raw-ip"' ]; then
		if [ -f /sys/class/net/$ifname/qmi/raw_ip ];then
			echo "Y" > /sys/class/net/$ifname/qmi/raw_ip
		else
			echo "Device only supports raw-ip mode but is missing this required driver attribute: /sys/class/net/$ifname/qmi/raw_ip"
		fi
	elif [ -n "`echo "$dataformat" | grep Failed`" ];then
		echo "Failed to connect to service"
		return 1
	else
		if [ -f /sys/class/net/$ifname/qmi/raw_ip ];then
			echo "N" > /sys/class/net/$ifname/qmi/raw_ip
		else
			echo "Device only supports 802.3 mode but is missing this required driver attribute: /sys/class/net/$ifname/qmi/raw_ip"
		fi
	fi

	#apn_use=1
	#profile_id=$(uci -q get network.$interface.id)
	#if [ -n "$profile_id" ]; then
	#apn_use=$(uci -q get apnprofile.$profile_id.apn_use)
	#fi
	pdp_type='-4'
	bus_str=$(echo $interface|cut -d '_' -f 2)
	if [ ${#bus_str} -eq 1 ]; then
		modem_bus=$(echo $INTERFACE | sed 's/modem_//g' | sed 's/_/-/' | sed 's/_/./')
	else
		modem_bus="$(get_modem_bus)"
	fi
	if [ "$ipv6" = "1" ]; then
		pdp_type='-4 -6'
		if [ "$apn_use" != "" ]; then
			[ -n "$modem_bus" ] && gl_modem -B $modem_bus AT AT+CGDCONT=$apn_use,\"IPV4V6\"
		fi
	fi

	[ -z "$apn" ] && {
		username=""
		password=""
		auth=""
	}

	[ -z "$username" ] && {
		password=""
		auth=""
	}

	[ -n "$mtu" ] && {
		echo "Setting MTU to $mtu"
		/sbin/ip link set dev $ifname mtu $mtu
	}

	if [ "$apn_use" != "-1" ];then
		if [ "$apn_use" != "" ]; then
			pdp_type='-4 -6'
			proto_run_command "$interface" qcm ${pdp_type:=-4 -6} \
				${cid:=-n $apn_use} \
				${apn:+-s $apn} \
				${username:+ $username} \
				${password:+ $password} \
				${auth:+ $auth} \
				${pincode:+-p $pincode}
		else
			proto_run_command "$interface" qcm ${pdp_type:=-4 -6} \
				${apn:+-s $apn} \
				${username:+ $username} \
				${password:+ $password} \
				${auth:+ $auth} \
				${pincode:+-p $pincode}
		fi
	else
		proto_run_command "$interface" qcm ${pdp_type:=-4 -6}
	fi

	# proto_run_command "$interface" qcm ${apn:+-s $apn} \
	# 		${username:+ $username} \
	# 		${password:+ $password} \
	# 		${auth:+ $auth} \
	# 		${pincode:+-p $pincode}

        proto_init_update "$ifname" 1                                                                                     
        proto_set_keep 1                                                                                     
        proto_send_update "$interface"

	time=`date '+%s'`
	json_init
	json_add_string name "${interface}_4"
	json_add_string ifname "@$interface"
	json_add_string proto "dhcp"
	json_add_string date "$time"
	proto_add_dynamic_defaults
	ubus call network add_dynamic "$(json_dump)"

	(sleep 3;path=`find  /sys/devices/ -name 'link_state'`;[ -n $path ] && echo "0x1" > $path) &
	return 0
}

proto_qcm_teardown() {
	local path=`find  /sys/devices/ -name 'link_state'`
	echo 0x0 > $path
	local interface="$1"
	proto_kill_command "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol qcm
}
