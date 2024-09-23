#!/bin/sh

netifd_update(){
	local interface="$1"
	ifup "$interface"
}

if [ "${ACTION}" = "REKEY-TIMEOUT"  -a "${ifname}" = "wgclient" ]; then
	# logger -t wireguard-debug `env`
	[ -f /tmp/wireguard/"${ifname}"_state ] || exit 0
	state="$(cat /tmp/wireguard/"${ifname}"_state)"
	[ "$state" = "connected" ] || exit 0
	
	echo "connecting" >/tmp/wireguard/"${ifname}"_state
	netifd_update $ifname
fi

if [ "${ACTION}" = "REKEY-GIVEUP"  -a "${ifname}" = "wgclient" ]; then
        logger -t wireguard-debug `env`
        echo "connecting" >/tmp/wireguard/"${ifname}"_state
        netifd_update $ifname
        echo f > /proc/net/nf_conntrack
fi
