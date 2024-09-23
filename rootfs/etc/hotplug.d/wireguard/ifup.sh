#!/bin/sh

. /lib/functions/gl_util.sh

handle_dns()
{
	echo -e "# Interface $1" > /tmp/resolv.conf.d/resolv.conf.wg

	if [ "${dns}" ]; then
		for d in ${dns};do
			case "${d}" in
				*,*)
					if [ "${d%%,*}" ]; then
						#proto_add_dns_server "${d%%,*}"
						echo -e "nameserver ${d%%,*}" >> /tmp/resolv.conf.d/resolv.conf.wg
					fi
					if [ "${d##*,}" ]; then
						#proto_add_dns_server "${d##*,}"
						echo -e "nameserver ${d##*,}" >> /tmp/resolv.conf.d/resolv.conf.wg
					fi
					;;
				*)
					if [ "${d%%,*}" ]; then
						#proto_add_dns_server "${d%%,*}"
						echo -e "nameserver ${d%%,*}" >> /tmp/resolv.conf.d/resolv.conf.wg
					fi
					;;
			esac
		done
	fi
}

netifd_update()
{
	. /lib/functions.sh
	. /lib/netifd/netifd-proto.sh

	local interface="$1"

	local peer_id
	local config
	local end_point
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
	local group_id

	config_load network
	config_get config "${interface}" "config"
	peer_id=${config#*_}

	config_load vpnpolicy
	config_get proxy_mode "route_policy" "proxy_mode" "0"

	config_load wireguard
	config_get end_point "${config}" "end_point"
	config_get public_key "${config}" "public_key"
	config_get private_key "${config}" "private_key"
	config_get listen_port "${config}" "listen_port"
	config_get address_v4 "${config}" "address_v4"
	config_get address_v6 "${config}" "address_v6"
	config_get preshared_key "${config}" "preshared_key"
	config_get allowed_ips "${config}" "allowed_ips"
	config_get_bool route_allowed_ips "${config}" "route_allowed_ips" 1
	config_get persistent_keepalive "${config}" "persistent_keepalive"
	config_get nohostroute "${config}" "nohostroute"
	config_get dns "${config}" "dns"
	config_get group_id "${config}" "group_id"
	[ -z "$dns" ] && config_get dns "group_${group_id}" "dns"

	proto_init_update "${interface}" 1 1
	proto_set_keep 1

	handle_dns "$interface"

	# endpoint dependency

	if [ "${nohostroute}" != "1" ]; then
		wg show "${interface}" endpoints | \
		sed -E 's/\[?([0-9.:a-f]+)\]?:([0-9]+)/\1 \2/' | \
		while IFS=$'\t ' read -r key address port; do
			[ -n "${port}" ] || continue
			echo "${address}" >/tmp/run/wg_resolved_ip
		done
	fi
	uci set firewall.block_dns.enabled='0'
	uci commit firewall
	proto_send_update "$interface"

	if [ ${proxy_mode} = "0" -o ${proxy_mode} = "3" -o ${proxy_mode} = "4" -o ${proxy_mode} = "5" ]; then
		[ -n "$dns" ] && {
			echo resolv-file=/tmp/resolv.conf.d/resolv.conf.wg > /tmp/dnsmasq.d/resolv.vpn
			create_restart_service /etc/init.d/dnsmasq
		}
	else
		[ -f "/tmp/dnsmasq.d/resolv.vpn" ] && {
			rm /tmp/dnsmasq.d/resolv.vpn
			create_restart_service /etc/init.d/dnsmasq
		}
	fi
	
	/etc/wireguard/scripts/wgclient-route-update.sh "${interface}" ${proxy_mode}

}

if [ "${ACTION}" = "KEYPAIR-CREATED" -a "${ifname}" = "wgclient" ]; then
	#logger -t wireguard-debug `env`
	[ -f /tmp/wireguard/"${ifname}"_state ] || exit 0
	state="$(cat /tmp/wireguard/"${ifname}"_state)"
	[ "$state" = "connecting" ] || exit 0
	if [ ! -f  /tmp/wireguard/"${ifname}"_boot ]; then
		exit 0
	fi
	rm -f /tmp/wireguard/"${ifname}"_boot

	netifd_update $ifname
	echo "connected" >/tmp/wireguard/"${ifname}"_state
fi
