#!/bin/sh

. /lib/functions.sh


delete_firewall()
{
	while [ true ];do
		[ ! -f /var/run/fw3.lock ] && break
		sleep 1
	done

	iptables -t mangle  -D PREROUTING -j VPN_SER_POLICY
	iptables -t mangle  -F VPN_SER_POLICY
	iptables -t mangle  -X VPN_SER_POLICY
}

make_firewall()
{
	while [ true ];do
		[ ! -f /var/run/fw3.lock ] && break
		sleep 1
	done

	iptables -t mangle -N VPN_SER_POLICY
	iptables -t mangle -A PREROUTING -j VPN_SER_POLICY
}

set_vpn_server_policy_firewall()
{
	local wgserver_disable="$(uci -q get network.wgserver.disabled)"
	local ovpnserver_disable="$(uci -q get network.ovpnserver.disabled)"

	local vpn_server_policy_wan="$(uci -q get vpnpolicy.global.vpn_server_policy)"

	#echo "===> call set_vpn_server_policy_firewall"

	if [ "${vpn_server_policy_wan}" == "1" ];then
		#vpn server through wan
		while [ true ];do
			[ ! -f /var/run/fw3.lock ] && break
			sleep 1
		done

		if [ "${wgserver_disable}" == "0" ];then

				iptables -t mangle -I VPN_SER_POLICY -i wgserver  -j MARK --set-mark 0x8000/0xc000
				iptables -t mangle -A VPN_SER_POLICY -i wgserver -j CONNMARK --save-mark --nfmask 0xc000 --ctmask 0xc000
		fi


		if [ "${ovpnserver_disable}" == "0" ];then

				iptables -t mangle -I VPN_SER_POLICY -i ovpnserver  -j MARK --set-mark 0x8000/0xc000
				iptables -t mangle -A VPN_SER_POLICY -i ovpnserver -j CONNMARK --save-mark --nfmask 0xc000 --ctmask 0xc000
		fi
	fi

	#vpn server not through wan, in the firewall clear VPN_SER_POLICY

}



#call func
delete_firewall
make_firewall
set_vpn_server_policy_firewall



