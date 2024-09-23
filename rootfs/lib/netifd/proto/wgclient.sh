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
	. /lib/functions/gl_util.sh
	init_proto "$@"
}

proto_wgclient_init_config() {
	proto_config_add_string config
	available=1
	no_proto_task=1
#	no_device=1
}

handle_dns() {
	status="$1"

	if [ ${status} = "up" ]; then
		[ -f "/tmp/dnsmasq.d/resolv.vpn" ] && {
			rm /tmp/dnsmasq.d/resolv.vpn
			create_restart_service /etc/init.d/dnsmasq
		}
	elif [ ${status} = "down" ]; then
		[ -f "/tmp/dnsmasq.d/resolv.vpn" ] && {
			rm /tmp/dnsmasq.d/resolv.vpn
			create_restart_service /etc/init.d/dnsmasq
		}
	fi
}

run_script() {
	local script="$1"
	local interface="$2"
	local config="$3"
	local ret

	${script} ${config}

	ret=$?

	if [ ${ret} -eq 1 ]
	then
	sleep 5
	proto_setup_failed "${interface}"
	exit 1
	fi
}

proto_wgclient_setup() {
	local interface="$1"
	local wg_dir="/tmp/wireguard"
	local wg_cfg="${wg_dir}/${interface}"
	local wg_state="${wg_dir}/${interface}"_state

	local config

	local end_point
	local end_point_ip
	local public_key
	local private_key
	local listen_port
	local fwmark
	local address_v4
	local address_v6
	local preshared_key
	local allowed_ips
	local route_allowed_ips
	local persistent_keepalive
	local nohostroute
	local global_proxy
	local dns
	local mtu
	local group_id
	config_load network
	config_get config "${interface}" "config"
	config_list_foreach "${interface}" pre_setup_script run_script "${interface}" "${config}"

	ip link del dev "${interface}" 2>/dev/null
	ip link add dev "${interface}" type wireguard

	#proto_init_update "${interface}" 1

	umask 077
	mkdir -p "${wg_dir}"
	echo "[Interface]" > "${wg_cfg}"

	config_load glconfig
	config_get proxy_mode "route_policy" "proxy_mode" "0"

	config_load wireguard
	config_get end_point "${config}" "end_point"
	config_get end_point_ip "${config}" "end_point_ip"
	config_get public_key "${config}" "public_key"
	config_get private_key "${config}" "private_key"
	config_get listen_port "${config}" "listen_port"
	config_get address_v4 "${config}" "address_v4"
	config_get address_v6 "${config}" "address_v6"
	config_get preshared_key "${config}" "preshared_key"
	config_get presharedkey_enable "${config}" "presharedkey_enable"
	config_get allowed_ips "${config}" "allowed_ips"
	config_get_bool route_allowed_ips "${config}" "route_allowed_ips" 0
	config_get persistent_keepalive "${config}" "persistent_keepalive"
	config_get nohostroute "${config}" "nohostroute"
	config_get dns "${config}" "dns"
	config_get mtu "${config}" "mtu"
	config_get fwmark "${config}" "fwmark" 0x8000

	config_get group_id "${config}" "group_id"
	[ -z "$private_key" ] && config_get private_key "group_${group_id}" "private_key"
	[ -z "$address_v4" ] && config_get address_v4 "group_${group_id}" "address_v4"
	[ -z "$address_v6" ] && config_get address_v6 "group_${group_id}" "address_v6"
	[ -z "$dns" ] && config_get dns "group_${group_id}" "dns"

	[ -n "$mtu" ] && {
		ip link set mtu "$mtu" "${interface}"
	}

	handle_dns up

	#rm -f "${wg_cfg}"

	echo "[Interface]" > "${wg_cfg}"
	if [ "${listen_port}" ]; then
		echo "ListenPort=${listen_port}" >> "${wg_cfg}"
	fi

	if [ "${fwmark}" ]; then
		echo "FwMark=${fwmark}" >> "${wg_cfg}"
	fi

	echo "PrivateKey=${private_key}" >> "${wg_cfg}"

	echo "[Peer]" >> "${wg_cfg}"
	echo "PublicKey=${public_key}" >> "${wg_cfg}"
	echo "Endpoint=${end_point_ip:-${end_point}}" >> "${wg_cfg}"
	if [ "${preshared_key}" ] && [ "${presharedkey_enable}" != "0" ]; then
		echo "PresharedKey=${preshared_key}" >> "${wg_cfg}"
	fi

	echo "AllowedIPs=${allowed_ips}" >> "${wg_cfg}"

	if [ -n "${persistent_keepalive}" -a ! "${persistent_keepalive}" = "0" ]; then
		echo "PersistentKeepalive=${persistent_keepalive}" >> "${wg_cfg}"
	else
		echo "PersistentKeepalive=25" >> "${wg_cfg}"
	fi

	# apply configuration file
	ip address add dev "${interface}" "$address_v4"
	[ -n "$address_v6" ] && ip -6 address add dev "${interface}" "$address_v6"
	${WG} setconf ${interface} "${wg_cfg}"
	WG_RETURN=$?

	rm -f "${wg_cfg}"

	if [ ${WG_RETURN} -ne 0 ]; then
		sleep 5
		proto_setup_failed "${interface}"
		exit 1
	fi
	echo connecting > "${wg_cfg}"_state
	touch "${wg_cfg}"_boot
	ip link set up dev "${interface}"
}

proto_wgclient_teardown() {
	local interface="$1"
	local wg_dir="/tmp/wireguard"
	local disabled="$(uci -q get network.${interface}.disabled)"
	local wg_state="${wg_dir}/${interface}"_state
	local kill_switch_en="$(uci -q get vpnpolicy.global.kill_switch)"
	local wan_access="$(uci -q get vpnpolicy.global.wan_access)"
	# 开启killswich或vpn客户端开启的情况下，接口down掉，始终阻止dns查询
	if [ "$wan_access" = 0 ]; then
		if [ "$kill_switch_en" = 1 -o "$disabled" = 0 ]; then
			uci set firewall.block_dns.enabled='1'
			uci commit firewall
			/etc/init.d/firewall reload
			/usr/bin/clean_client_conntrack
		fi
	fi

	if [ "$disabled" = "0" ];then
		echo "connecting" > "${wg_state}"
	else
		rm "${wg_state}"
	fi
	ip link del dev "${interface}" >/dev/null 2>&1
	handle_dns down
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol wgclient
}
