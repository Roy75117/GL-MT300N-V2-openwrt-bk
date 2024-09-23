#!/bin/sh
[ -x /usr/sbin/openvpn ] || exit 0

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	. /lib/functions/gl_util.sh
	init_proto "$@"
}

proto_ovpnclient_init_config() {
	no_device=1
	available=1
	#no-proto-task=1
	proto_config_add_string config
	proto_config_add_defaults
}

handle_dns() {
	status="$1"

	if [ ${status} = "up" ]; then
		[ -f "/tmp/dnsmasq.d/resolv.vpn" ] && {
			rm /tmp/dnsmasq.d/resolv.vpn
			/etc/init.d/dnsmasq restart
		}
	elif [ ${status} = "down" ]; then
		[ -f "/tmp/dnsmasq.d/resolv.vpn" ] && {
			rm /tmp/dnsmasq.d/resolv.vpn
			/etc/init.d/dnsmasq restart
		}
	fi
}

proto_ovpnclient_setup() {
	local interface="$1"
	local config
	local ovpn_cfg apply_cfg
	local dev_type="tun"
	local proxy_mode
	json_get_vars config

	config_load vpnpolicy
	config_get proxy_mode "route_policy" "proxy_mode" "0"

	config_load ovpnclient
	config_get ovpn_cfg "${config}" "path"
	handle_dns up
	
	[ -f "$ovpn_cfg" ] || {
		proto_notify_error "$interface" CONFIG_NOT_FOUND
		exit 1
	}

	[ -d "/tmp/ovpnclient" ] || mkdir -p "/tmp/ovpnclient"
	apply_cfg="/tmp/ovpnclient/${interface}"
	rm -f "${apply_cfg}"

	[ -n "$(cat "${ovpn_cfg}"|grep 'dev-type'|grep tap)" ] && dev_type="tap"

	#copy the raw file and fix some options
	#remove option daemon dev and dev-type
	sed  -e '/daemon/d'  -e '/dev /d' -e '/dev-type/d' "${ovpn_cfg}" > "${apply_cfg}"
	
	echo "connecting" > ${apply_cfg}_state


	proto_run_command "$interface" /usr/sbin/openvpn \
		--syslog 'ovpnclient' \
		--dev "${interface}" \
		--dev-type "${dev_type}" \
		--route-delay 2 \
		--route-noexec \
		--writepid "/var/run/ovpnclient-${interface}.pid" \
		--script-security 3 \
		--config "${apply_cfg}" \
		--remap-usr1 SIGHUP \
		--up "/etc/openvpn/scripts/ovpnclient-up ${interface} ${proxy_mode}" \
		--down "/etc/openvpn/scripts/ovpnclient-down ${interface}" \
		--pull-filter ignore ifconfig-ipv6 \
		--mark 32768 --allow-recursive-routing
}

proto_ovpnclient_teardown() {
	local interface="$1"
	local disabled="$(uci -q get network.${interface}.disabled)"
	local pid="$(cat /var/run/ovpnclient-ovpnclient.pid 2>/dev/null)"
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
		echo "connecting" > /tmp/ovpnclient/${interface}_state
	else
		rm -f /tmp/ovpnclient/${interface}_state
	fi

	handle_dns down

	#openvpn exiting due fatal error, block proro restart
	[ -z "$pid" ] && {
		#proto_init_update "$interface" 1
		#proto_setup_failed "$interface"
		#proto_block_restart
		#proto_send_update "$interface"
		#proto_notify_error "$interface" OPENVPN_EXITING_DUE_FATAL_ERROR
		logger 'openvpn process exit and try again 5 seconds later'
		sleep 5
	}
	[ -n "$pid" ] && {
		kill -9 "$pid"
		ip link del dev "$interface" 
	}
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol ovpnclient
}

