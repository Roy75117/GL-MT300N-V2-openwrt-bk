#!/bin/sh

# include netifd library
. /lib/functions.sh
#. /lib/netifd/netifd-proto.sh

interface="$1"
proxy_mode="$2"

logger -t wgclient-up "env value:"`env`

custom_route_rules()
{
	local rule_peer_id
	local route_flag
	local dest
	local mask
	local gateway
	local metric
	local scope
	local mtu

	config_get rule_peer_id "$1" "peer_id"
	config_get route_flag "$1" "route_flag"
	config_get dest "$1" "dest"
	config_get mask "$1" "mask"
	config_get gateway "$1" "gateway"
	config_get metric "$1" "metric"
	config_get mtu "$1" "mtu"
	config_get scope "$1" "scope"

	#logger -t wgclient-up "rule_peer_id=${rule_peer_id}, route_flag=${route_flag}, dest=${dest}, mask=${mask}, gateway=${gateway}, metric=${metric}, mtu=${mtu}"

	if [ -n "${mtu}" ]; then
		route_option="metric ${metric} mtu ${mtu}"
	else
		route_option="metric ${metric}"
	fi

	if [ ${peer_id} = ${rule_peer_id} ]; then
		if [ ${route_flag} = "4" ]; then
			if [ ${action} = "add" ]; then
				ip route add "${dest}"/"${mask}" ${gateway:+via $gateway} dev "${interface}"   ${scope:+scope $scope} ${route_option}
			else
				ip route del "${dest}"/"${mask}" ${gateway:+via $gateway} dev "${interface}"   ${scope:+scope $scope}
			fi
		elif [ ${route_flag} = "6" ]; then
			if [ ${action} = "add" ]; then
				ip -6 route add "${dest}"/"${mask}" ${gateway:+via $gateway} dev "${interface}"  ${scope:+scope $scope} ${route_option}
			else
				ip -6 route del "${dest}"/"${mask}" ${gateway:+via $gateway}  dev "${interface}"  ${scope:+scope $scope}
			fi
		fi
	fi
}

custom_route_settings()
{
	local action="$1"
	local config
	local peer_id

	config_load network
	config_get config "${interface}" "config"
	peer_id=${config#*_}

	config_load wireguard
	config_foreach custom_route_rules route_rules
}

auto_route_settings()
{
	local action="$1"
	local config
	local route_allowed_ips

	config_load network
	config_get config "${interface}" "config"

	config_load wireguard
	config_get allowed_ips "${config}" "allowed_ips"
	config_get_bool route_allowed_ips "${config}" "route_allowed_ips" 1

	if [ ${route_allowed_ips} -ne 0 ]; then
		trimmed_allowed_ips=`echo ${allowed_ips} | tr ',' ' '`
		if [ ${action} = "add" ]; then
			for allowed_ip in ${trimmed_allowed_ips}; do
				case "${allowed_ip}" in
					*:*/*)
						if [ "${allowed_ip}" = "::/0" ]; then
							ip -6 route add default dev "${interface}" table 8000
						else
							ip -6 route add "${allowed_ip%%/*}"/"${allowed_ip##*/}" dev "${interface}"
						fi
						;;
					*.*/*)
						if [ "${allowed_ip%%,*}" = "0.0.0.0/0" ]; then
							ip route add default dev "${interface}" table 8000
						else
							local mask=${allowed_ip##*/}
							ip route add "${allowed_ip%%/*}"/"${mask%%,*}" dev "${interface}"
						fi
						;;
					*:*)
						ip -6 route add "${allowed_ip%%/*}"/128 dev "${interface}"
						;;
					*.*)
						ip route add "${allowed_ip%%/*}"/32 dev "${interface}"
						;;
				esac                                                                        
			done                                                                                
		elif [ ${action} = "del" ]; then
			for allowed_ip in ${trimmed_allowed_ips}; do
				case "${allowed_ip}" in
					*:*/*)
						if [ "${allowed_ip}" = "::/0" ]; then
							ip -6 route del default dev "${interface}" table 8000
						else
							ip -6 route del "${allowed_ip%%/*}"/"${allowed_ip##*/}" dev "${interface}"
						fi
						;;
					*.*/*)
						if [ "${allowed_ip%%,*}" = "0.0.0.0/0" ]; then
							ip route del default dev "${interface}" table 8000
						else
							local mask=${allowed_ip##*/}
							ip route del "${allowed_ip%%/*}"/"${mask%%,*}" dev "${interface}"
						fi
						;;
					*:*)
						ip -6 route del "${allowed_ip%%/*}"/128 dev "${interface}"
						;;
					*.*)
						ip route del "${allowed_ip%%/*}"/32 dev "${interface}"
						;;
				esac                                                                        
			done                                                                                
		fi
	fi
}

global_proxy_settings()
{
	local action="$1"

	if [ ${action} = "add" ]; then
		ip route add default dev "${interface}" table 8000
		ip -6 route add default dev "${interface}" table 8000
	elif [ ${action} = "del" ]; then
		ip route del default dev "${interface}" table 8000
		ip -6 route del default dev "${interface}" table 8000
	fi
}


#proto_init_update "${interface}" 1
#proto_set_keep 1

if [ ${proxy_mode} = "0" ]; then
	auto_route_settings del
	custom_route_settings del
	global_proxy_settings add
elif [ ${proxy_mode} = "1" ]; then
	global_proxy_settings del
	custom_route_settings del
	auto_route_settings add
elif [ ${proxy_mode} = "2" ]; then
	global_proxy_settings del
	auto_route_settings del
	custom_route_settings add
elif [ ${proxy_mode} = "3" ]; then
	auto_route_settings del
	custom_route_settings del
        global_proxy_settings add
elif [ ${proxy_mode} = "4" ]; then
	auto_route_settings del
	custom_route_settings del
        global_proxy_settings add
elif [ ${proxy_mode} = "5" ]; then
	auto_route_settings del
	custom_route_settings del
        global_proxy_settings add
fi

echo f >/proc/net/nf_conntrack

exit 0
