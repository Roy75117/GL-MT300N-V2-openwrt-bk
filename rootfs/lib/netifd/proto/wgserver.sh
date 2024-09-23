#!/bin/sh
# Copyright 2016-2017 Dan Luedtke <mail@danrl.com>
# Licensed to the public under the Apache License 2.0.

WG=/usr/bin/wg
if [ ! -x $WG ]; then
	logger -t "wireguard" "error: missing wireguard-tools (${WG})"
	exit 0
fi

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

proto_wgserver_init_config() {
	proto_config_add_int "config"
	available=1
	no_proto_task=1
}

detect_route_allowed(){
	local config="$1"
	local detect="$2"
	local gateway
	local mask
	local dest
	config_get gateway "$config" "gateway"
	[ "$detect" = "$gateway" ] && {
		config_get dest "$config" "dest"
		config_get mask "$config" "mask"
		echo "AllowedIPs=${dest}/${mask}" >> "${wg_cfg}"
	}
}

add_route_rules() {
	local route_flag
	local dest
	local mask
	local gateway
	local metric
	local mtu

	config_get route_flag "$1" "route_flag"
	config_get dest "$1" "dest"
	config_get mask "$1" "mask"
	config_get gateway "$1" "gateway"
	config_get metric "$1" "metric"
	config_get mtu "$1" "mtu"

	logger -t wgserver-route "route_flag=$route_flag, dest=$dest, mask=$mask, gateway=$gateway, metric=$metric, mtu=$mtu"

	if [ $route_flag = "4" ]; then
		#proto_add_ipv4_route "$dest" "$mask" "$gateway" "" "$metric"
		ip route add "$dest"/"$mask" ${gateway:+via $gateway} dev "wgserver" ${scope:+scope $scope} ${mtu:+mtu $mtu} ${metric:+metric $metric}
	elif [ $route_flag = "6" ]; then
		ip -6 route add "$dest"/"$mask" ${gateway:+via $gateway} dev "wgserver" ${scope:+scope $scope} ${mtu:+mtu $mtu} ${metric:+metric $metric}
		#proto_add_ipv6_route "$dest" "$mask" "$gateway" "$metric"
	fi
}

load_peers() {
	local config="$1"

	local public_key
	local preshared_key
	local client_ip
	local persistent_keepalive

	config_get public_key "${config}" "public_key"
	config_get preshared_key "${config}" "presharedkey"
	config_get client_ip "${config}" "client_ip"
	config_get persistent_keepalive "${config}" "persistent_keepalive"

	echo "[Peer]" >> "${wg_cfg}"
	echo "PublicKey=${public_key}" >> "${wg_cfg}"
	if [ "${preshared_key}" ]; then
		echo "PresharedKey=${preshared_key}" >> "${wg_cfg}"
	fi

	echo "AllowedIPs=${client_ip%%/*}" >> "${wg_cfg}"
	config_foreach detect_route_allowed route_rules ${client_ip%%/*}

	if [ "${persistent_keepalive}" ]; then
		echo "PersistentKeepalive=${persistent_keepalive}" >> "${wg_cfg}"
	fi

}

proto_wgserver_setup() {
	local interface="$1"
	local wg_dir="/tmp/wireguard"
	local wg_cfg="${wg_dir}/${interface}"

	local config

	local public_key
	local private_key
	local listen_port
	local fwmark
	local address_v4
	local address_v6
	local mtu

	config_load network
	config_get config "${interface}" "config"

	ip link del dev "${interface}" 2>/dev/null
	ip link add dev "${interface}" type wireguard

	proto_init_update "${interface}" 1

	umask 077
	mkdir -p "${wg_dir}"

	config_load wireguard_server
	config_get public_key "${config}" "public_key"
	config_get private_key "${config}" "private_key"
	config_get listen_port "${config}" "port"
	config_get fwmark "${config}" "fwmark" '0x8000'
	config_get address_v4 "${config}" "address_v4"
	config_get address_v6 "${config}" "address_v6"
	config_get mtu "${config}" "mtu"
	
	rm -f "${wg_cfg}"
	echo "[Interface]" > "${wg_cfg}"
	echo "PrivateKey=${private_key}" >> "${wg_cfg}"
	if [ "${listen_port}" ]; then
		echo "ListenPort=${listen_port}" >> "${wg_cfg}"
	fi
	if [ "${fwmark}" ]; then
		echo "FwMark=${fwmark}" >> "${wg_cfg}"
	fi
	[ -n "$mtu" ] && ip link set mtu "$mtu" "${interface}"

	config_foreach load_peers  peers

	# apply configuration file
	${WG} setconf ${interface} "${wg_cfg}"
	WG_RETURN=$?

	if [ ${WG_RETURN} -ne 0 ]; then
		sleep 5
		proto_setup_failed "${interface}"
		exit 1
	fi

	if [ "$address_v4" ];then
		case "${address_v4}" in
			*.*/*)
				proto_add_ipv4_address "${address_v4%%/*}" "${address_v4##*/}"
				;;
			*.*)
				proto_add_ipv4_address "${address_v4%%/*}" "32"
				;;
		esac
	fi
	if [ "$address_v6" ];then
		case "${address_v6}" in
			*:*/*)
				proto_add_ipv6_address "${address_v6%%/*}" "${address_v6##*/}"
				;;
			*:*)
				proto_add_ipv6_address "${address_v6%%/*}" "128"
				;;
		esac
	fi

	# add custom route rules
	#config_foreach add_route_rules route_rules

	proto_send_update "${interface}"
	config_foreach add_route_rules route_rules
}

proto_wgserver_teardown() {
	local interface="$1"
	ip link del dev "${interface}" >/dev/null 2>&1
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol wgserver
}
