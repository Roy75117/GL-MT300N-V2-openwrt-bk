#!/bin/sh

. /lib/functions/gl_util.sh
. /lib/functions.sh

DHCP_FILE="/tmp/dnsmasq.d/drop-in-dhcp"
DHCP_INFO="/tmp/drop-in-dhcp-info"

WAN="$(get_wan)"
POOL_START=""
POOL_END=""
POOL_NETMASK=""
POOL_LEASETIME=""
UPSTREAM_GATEWAY=""
UPSTREAM_DNS=""
LOCAL_IPADDR=""

add_parental_control_dev()
{
    [ -f "/etc/config/parental_control" ] && {
        uci -q del_list parental_control.global.src_dev="$WAN"
        uci -q add_list parental_control.global.src_dev="$WAN"
        uci commit
        /etc/init.d/parental_control restart
    }
}

remove_parental_control_dev()
{
    [ -f "/etc/config/parental_control" ] && {
        uci -q del_list parental_control.global.src_dev="$WAN"
        uci commit
        /etc/init.d/parental_control restart
    }
}

load_edgerouter_config()
{
    config_load edgerouter
    config_get POOL_START "wandhcp" "start"
    config_get POOL_END "wandhcp" "end"
    config_get POOL_NETMASK "wandhcp" "netmask"
    config_get POOL_LEASETIME "wandhcp" "leasetime"
    config_get LOCAL_IPADDR "wandhcp" "ip"
    config_get UPSTREAM_GATEWAY "wandhcp" "gateway"
    config_get UPSTREAM_DNS "wandhcp" "dns"
}

setup_drop_in_interface()
{
    uci rename network.wan='wan_ori'
    uci set network.wan_ori.disabled="1"
    uci commit
    uci set network.wan="interface"
    if [ "$(cat /etc/os-release|grep VERSION|head -n1|awk -F "[=\".]" '{print $3}')" -gt 19 ];then
        uci set network.wan.device="$WAN"
    else
        uci set network.wan.ifname="$WAN"
    fi
    uci set network.wan.proto="static"
    uci set network.wan.ipaddr="$LOCAL_IPADDR"
    uci set network.wan.gateway="$UPSTREAM_GATEWAY"
    uci set network.wan.netmask="$POOL_NETMASK"
    uci set network.wan.peerdns="0"
    uci set network.wan.dns="$UPSTREAM_DNS"
    
    uci commit
    /etc/init.d/network reload

    echo a "$WAN" >/proc/oui-tertf/subnet
    add_parental_control_dev
}

remove_drop_in_interface()
{
    [ -n "$(uci -q get network.wan_ori)" ] && {
        uci -q del network.wan
        uci commit
        uci set network.wan_ori.disabled="0"
        uci rename network.wan_ori='wan'
        uci commit
        /etc/init.d/network reload
    }
    echo d "$WAN" >/proc/oui-tertf/subnet
    remove_parental_control_dev
}

setup_dhcp_for_drop_in()
{
    uci set dhcp.wan.start=${POOL_START}
    uci set dhcp.wan.limit=$((POOL_END-POOL_START))
    uci set dhcp.wan.leasetime=${POOL_LEASETIME}
    uci set dhcp.wan.force=1
    uci rename dhcp.wan.ignore='ignore_ori'
    uci commit
    #echo "dhcp-range=set:drop_in,${POOL_START},${POOL_END},${POOL_NETMASK},${POOL_LEASETIME}" >$DHCP_FILE
    /etc/init.d/dnsmasq restart
}

remove_dhcp_for_drop_in()
{
    [ -n "$(uci -q get dhcp.wan.ignore_ori)" ] && {
        uci rename dhcp.wan.ignore_ori='ignore'
        uci delete dhcp.wan.start
        uci delete dhcp.wan.limit
        uci delete dhcp.wan.leasetime
        uci delete dhcp.wan.force
        uci commit
    }
    #rm $DHCP_FILE
    /etc/init.d/dnsmasq restart
}

check_dhcp_server()
{
    local INFO
    INFO="$(dhcpdiscover -i ${WAN} -p -t 4 ${LOCAL_IPADDR:+-b $LOCAL_IPADDR} )"
    if [ -n "$INFO" ];then
        echo -e "$INFO" > $DHCP_INFO
    else
        rm $DHCP_INFO 2>/dev/null
    fi
}

load_edgerouter_config