#!/bin/sh
[ -x /usr/sbin/openvpn ] || exit 0

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

proto_ovpnserver_init_config() {
	no_device=1
	available=1
}

add_iroute_rules() {
	local route_flag
	local dest
	local mask
	local gateway
	local vpn_mask="$2"
	local vpn_subnet="$3"

	local ccd_dir=/etc/openvpn/ccd
	local iroute_cfg=/etc/openvpn/ccd/DEFAULT

	[ -d "$ccd_dir" ] || mkdir -p "$ccd_dir"

	config_get route_flag "$1" "route_flag"
	config_get dest "$1" "dest"
	config_get mask "$1" "mask"
	config_get gateway "$1" "gateway"

	if [ $route_flag = "4" ]; then
		if [ -n "$gateway" ]; then
			gateway_subnet=$(ipcalc.sh $gateway $vpn_mask | awk -F= '/NETWORK/{print $2}')
			[ $vpn_subnet != $gateway_subnet ] && return
		fi

		dest_ip=$(ipcalc.sh $dest $mask | awk -F= '/NETWORK/{print $2}')
		netmask=$(ipcalc.sh $dest $mask | awk -F= '/NETMASK/{print $2}')
		echo "iroute $dest_ip $netmask" >> $iroute_cfg
	elif [ $route_flag = "6" ]; then
		echo "iroute-ipv6 $dest/$mask" >> $iroute_cfg
	fi
}

load_config() {
	local cfg="$1"
	local auth
	local proto
	local port
	local dev
	local dev_type
	local cipher
	local comp
	local subnetv4
	local subnetv6
	local mask
	local start
	local end
	local verb
	local ca
	local key
	local cert
	local dh
	local ta
	local ipv6_enable
	local server
	local server_ipv6
	local global_ipv6_enable
	local lzo
	local compress
	local client_to_client
	local client
	local hmac
	local client_auth
	local tap_address
	local tap_mask
	local mtu

	config_load glipv6
	config_get global_ipv6_enable "globals" "enabled"

	local config="vpn"

	config_load ovpnserver

	config_get auth "${config}" "auth"
	config_get proto "${config}" "proto"
	config_get port "${config}" "port"
	config_get dev "${config}" "dev"
	config_get dev_type "${config}" "dev_type"
	config_get cipher "${config}" "cipher"
	config_get comp "${config}" "comp"
	config_get subnetv4 "${config}" "subnetv4"
	config_get subnetv6 "${config}" "subnetv6"
	config_get mask "${config}" "mask"
	config_get start "${config}" "start"
	config_get end "${config}" "end"
	config_get verb "${config}" "verb"
	config_get ipv6_enable "${config}" "ipv6_enable"
	config_get lzo "${config}" "lzo"
	config_get client_to_client "${config}" "client_to_client"
	config_get hmac "${config}" "hmac"
	config_get client_auth "${config}" "client_auth"
	config_get tap_address "${config}" "tap_address"
	config_get tap_mask "${config}" "tap_mask"
	config_get mtu "global" "mtu"

	if [ "${dev_type}" = "tun" ]; then
		server="server ${subnetv4} ${mask:="255.255.255.0"}"
		if [ "${global_ipv6_enable}" = "1" -a "${ipv6_enable}" = "1" ]; then
			server_ipv6="server-ipv6 ${subnetv6}"
		fi
	elif [ "${dev_type}" = "tap" ]; then
		server="server-bridge ${tap_address} ${tap_mask:="255.255.255.255"} ${start} ${end}"
	fi

	if [ "${lzo}" = "1" ]; then
		compress="comp-lzo"
	fi

	if [ "${client_to_client}" = "1" ]; then
		client="client-to-client"
	fi

cat > ${cfg} << EOF                                                                  
${client}
persist-key
persist-tun
auth ${auth:="SHA256"}
cipher ${cipher:="AES-128-CBC"}
ncp-disable
dev ${dev:="ovpnserver"}
dev-type ${dev_type:="tun"}
group nogroup
keepalive 10 120
mode server
mute 5
port ${port:="1194"}
proto ${proto:="udp"}
push "persist-key"
push "persist-tun"
push "redirect-gateway def1"
route-gateway dhcp
client-config-dir /etc/openvpn/ccd
topology subnet
duplicate-cn
user nobody
mark 32768
verb ${verb:="3"}
${server}
${server_ipv6}
${compress}
EOF

	if [ "${client_auth}" = "2" ]; then
		echo "script-security 3" >> ${cfg}
		echo "auth-user-pass-verify /etc/openvpn/scripts/checkpsw.sh via-env" >> ${cfg}
		echo "verify-client-cert none" >> ${cfg}
		echo "username-as-common-name" >> ${cfg}
	elif [ "${client_auth}" = "3" ]; then
		echo "script-security 3" >> ${cfg}
		echo "auth-user-pass-verify /etc/openvpn/scripts/checkpsw.sh via-env" >> ${cfg}
		echo "username-as-common-name" >> ${cfg}
	fi

	[ -n "$mtu" ] && echo "tun-mtu $mtu" >> ${cfg}

	ca="$(cat /etc/openvpn/cert/ca.crt)"
	cert="$(cat /etc/openvpn/cert/server.crt)"
	key="$(cat /etc/openvpn/cert/server.key)"
	dh="$(cat /etc/openvpn/cert/dh1024.pem)"
	ta="$(cat /etc/openvpn/cert/ta.key)"

	[ -n "${ca}" ] && {
		echo "<ca>" >> ${cfg}
		echo "${ca}" >> ${cfg}
		echo "</ca>" >> ${cfg}
	}

	[ -n "${cert}" ] && {
		echo "<cert>" >> ${cfg}
		echo "${cert}" >> ${cfg}
		echo "</cert>" >> ${cfg}
	}

	[ -n "${key}" ] && {
		echo "<key>" >> ${cfg}
		echo "${key}" >> ${cfg}
		echo "</key>" >> ${cfg}
	}
	if [ -n "$(grep SAyVAhdDpHkJ5rAgEC /etc/openvpn/cert/dh1024.pem)" ]; then
		echo "dh none" >>${cfg}
	else
		[ -n "${dh}" ] && {
			echo "<dh>" >> ${cfg}
			echo "${dh}" >> ${cfg}
			echo "</dh>" >> ${cfg}
		}
	fi

	if [ "${hmac}" = "1" ]; then
		echo "<tls-auth>" >> ${cfg}
		echo "${ta}" >> ${cfg}
		echo "</tls-auth>" >> ${cfg}
	fi

	[ -f "/etc/openvpn/ccd/DEFAULT" ] && rm "/etc/openvpn/ccd/DEFAULT"
	config_foreach add_iroute_rules route_rules $mask $subnetv4
}

proto_ovpnserver_setup() {
	local interface="$1"
	local ovpn_cfg="/tmp/ovpnserver/${interface}"
	
	[ -d "/var/log/ovpnserver" ] || mkdir -p "/var/log/ovpnserver"
	[ -d "/tmp/ovpnserver" ] || mkdir -p "/tmp/ovpnserver"

	rm -f "$ovpn_cfg"
	load_config "$ovpn_cfg"
	#set -x
	proto_run_command "$interface" /usr/sbin/openvpn \
		--syslog 'ovpnserver' \
		--writepid "/var/run/ovpnserver-${interface}.pid" \
		--script-security 2 \
		--config "${ovpn_cfg}" \
		--up "/etc/openvpn/scripts/ovpnserver-up $interface" 
		#--pull-filter ignore ifconfig-ipv6 \
		#--pull-filter ignore route-ipv6 
	#set +x
}

proto_ovpnserver_teardown() {
	local interface="$1"
	
	#killall -9 openvpn
	proto_kill_command "$interface"
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol ovpnserver
}

