. /usr/share/libubox/jshn.sh
LTE=" 1 2 3 4 5 7 8 12 13 14 17 18 19 20 25 26 28 29 30 32 34 38 39 40 41 42 43 46 48 66 71 "
SA=" 1 2 3 5 7 8 12 13 14 18 20 25 26 28 29 30 38 40 41 48 66 70 71 75 76 77 78 79 "
NSA=" 1 2 3 5 7 8 12 13 14 18 20 25 26 28 29 30 38 40 41 48 66 70 71 75 76 77 78 79 "

get_modem_bus()
{
    local modem_bus="1-1.2"
    node=$(uci -q get glmodem.global.usbnode)
    if [ -z "$node" ]; then
        build_in="$(cat /proc/gl-hw-info/build-in-modem 2>/dev/null)"
        [ -z "$build_in" -a "$1" = "usb" ] && build_in="$(cat /proc/gl-hw-info/usb-port 2>/dev/null)"
    else
        build_in=$node
    fi

    if [ "$(echo $build_in | grep -q ',';echo $?)" = "0" ]; then
        build_in_array="${build_in/,/ }"
        for modem in $build_in_array; do
            if [ -z "$(echo $modem | grep '-')" ]; then
                ls /sys/bus/pci/devices/* | grep -q "$modem" && modem_bus=$modem ;break
            else
                ls /tmp/usbnode/* | grep -q "$modem" && modem_bus=$modem ;break
            fi
        done
    elif [ -z "$(echo $build_in | grep '-')" ]; then
        ls /sys/bus/pci/devices/* |grep -q "$build_in"
        [ "$(echo $?)" = "0" ] && modem_bus=$build_in
    else
        ls /tmp/usbnode/* | grep -q "$build_in"
        [ "$(echo $?)" = "0" ] && modem_bus=$build_in
    fi
    echo $modem_bus
}

get_modem_iface()
{
    local modem_iface=""
    local bus=$1
    [ -z "$bus" ] && bus=$(get_modem_bus)
    if [ -n "$(echo $bus | grep ':')" -a -e "/proc/gl-hw-info/pcie-bus" ] && [[ $(cat /proc/gl-hw-info/pcie-bus 2>/dev/null) == *$bus* ]];then
        modem_iface="modem_$(echo ${bus%%:*})"
    elif [ -n "$(echo $bus | grep '-')" ]; then
        modem_iface="modem_$(echo $bus | sed 's/-/_/g' | sed 's/\./_/g')"
    fi
    echo $modem_iface
}

band2hex()
{
    local band="$@"
    local l=0;
    local h=0;
    for i in $band;do
        let i=i-1
        if [ $i -lt 64 ];then
            v=$((1<<$i))
            let l=l+v
        else
            let i=i-64
            v=$((1<<$i))
            let h=h+v
        fi
    done
    if [ $h -gt 0 ];then
        printf "%x%016x" $h $l
    else
        printf "%x" $l
    fi
}

allow_bands()
{
    [ -f "/proc/gl-hw-info/build-in-modem" ] || return
    local mode="$1"
    local bands=`echo $2 | sed 's/ /:/g'`
    local bus=$(get_modem_bus)

    [ "$bands" = "" ] && bands=$(eval echo \$$mode | sed 's/ /:/g')

    case $mode in
        *LTE*)
            local hex
            [ -n "$2" ] &&  hex="$(band2hex $2)" || hex="$(band2hex $LTE)"
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"lte_band\",$bands\'
            eval gl_modem -B $bus AT \'AT+QCFG=\"band\",0,$hex\'
        ;;
        SA*)
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_band\",$bands\'
        ;;
        *NSA*)
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nsa_nr5g_band\",$bands\'
        ;;
    esac
}

disable_bands()
{
    local mode="$1"
    local dis_bands="$2"

    local bands=$(eval echo \$$mode)
    for dis_band in $dis_bands
    do
        bands=`echo $bands | sed 's/\<'"$dis_band"'\>//'`
    done

    allow_bands "$mode" "$bands"
}

set_5G_mode()
{
    local lte_band="$1"
    local sa_band="$2"
    local nsa_band="$3"
    local bus=$(get_modem_bus)

    if [ "$lte_band" = "" -a "$sa_band" = "" -a "$nsa_band" = "" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",AUTO\'
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",0\'
    elif [ "$lte_band" = "" ] && [ "$sa_band" != "" -o "$nsa_band" != "" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",NR5G\'
        if [ "$sa_band" != "" -a "$nsa_band" = "" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",2\'
        elif [ "$sa_band" = "" -a "$nsa_band" != "" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",1\'
        elif [ "$sa_band" != "" -a "$nsa_band" != "" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",0\'
        fi
    elif [ "$lte_band" != "" ] && [ "$sa_band" != "" -o "$nsa_band" != "" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",AUTO\'
        if [ "$sa_band" != "" -a "$nsa_band" = "" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",2\'
        elif [ "$sa_band" = "" -a "$nsa_band" != "" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",1\'
        elif [ "$sa_band" != "" -a "$nsa_band" != "" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",0\'
        fi
    elif [ "$lte_band" != "" ] && [ "$sa_band" = "" -o "$nsa_band" = "" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",LTE\'
    fi
}

set_5G_mode_mask()
{
    local lte_band="$1"
    local sa_band="$2"
    local nsa_band="$3"
    local bus=$(get_modem_bus)

    if [ "$lte_band" = "" -a "$sa_band" = "" -a "$nsa_band" = "" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",AUTO\'
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",0\'
    elif [ " $lte_band " = "$LTE" ] && [ " $sa_band " != "$SA" -o " $nsa_band " != "$NSA" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",NR5G\'
        if [ " $sa_band " != "$SA" -a " $nsa_band " = "$NSA" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",2\'
        elif [ " $sa_band " = "$SA" -a " $nsa_band " != "$NSA" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",1\'
        elif [ " $sa_band " != "$SA" -o " $nsa_band " != "$NSA" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",0\'
        fi
    elif [ " $lte_band " != "$LTE" ] && [ " $sa_band " != "$SA" -o " $nsa_band " != "$NSA" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",AUTO\'
        if [ " $sa_band " != "$SA" -a " $nsa_band " = "$NSA" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",2\'
        elif [ " $sa_band " = "$SA" -a " $nsa_band " != "$NSA" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",1\'
        elif [ " $sa_band " != "$SA" -o " $nsa_band " != "$NSA" ];then
            eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",0\'
        fi
    elif [ " $lte_band " != "$LTE" ] && [ " $sa_band " = "$SA" -o " $nsa_band " = "$NSA" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",LTE\'
    else
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",WCDMA\'
    fi

}

set_4G_mode()
{
    local lte_band="$1"

    if [ " $lte_band " != "" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",LTE\'
    else
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",AUTO\'
    fi
}

set_4G_mode_mask()
{
    local lte_band="$1"

    if [ " $lte_band " = "$LTE" ];then
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",WCDMA\'
    fi
}

handle_bands()
{
    local version=""
    local bus=$(get_modem_bus)
    for count in $(seq 1 10)
    do
        version=`gl_modem -B $bus AT ATI | grep Revision: | awk '{print $2}'`
        [ "$version" != "" ] && break
        sleep 1
    done

    local interface="$1"
    [ -n "$interface" ] || return
    local band_filter=`uci -q get network.$interface.band_filter_mode`
    local band_list=`uci -q get network.$interface.band_list`
    json_load "$band_list"
    json_get_values "lte" "LTE"
    case $version in
        *RM520NGL*)
            json_get_values "sa" "NR-SA"
            json_get_values "nsa" "NR-NSA"
            [ -z "$band_filter" -o "$band_filter" = "0" ] && {
                set_5G_mode "$lte" "$sa" "$nsa"
                allow_bands "LTE" "$lte"
                allow_bands "SA" "$sa"
                allow_bands "NSA" "$nsa"
            }
            [ "$band_filter" = "1" ] && {
                set_5G_mode_mask "$lte" "$sa" "$nsa"
                [ " $lte " != "$LTE" ] && disable_bands "LTE" "$lte"
                [ " $sa" != "$SA" ] && disable_bands "SA" "$sa"
                [ " $nsa" != "$NSA" ] && disable_bands "NSA" "$nsa"
            }
        ;;
        *)
            [ -z "$band_filter" -o "$band_filter" = "0" ] && {
                set_4G_mode
                allow_bands "LTE" "$lte"
            }
            [ "$band_filter" = "1" ] && {
                set_4G_mode_mask "$lte"
                disable_bands "LTE" "$lte"
            }
        ;;
    esac

}

modem_AT_set_band()
{
    local modem_iface=""
    local bus=$(get_modem_bus)
    if [ -f "/proc/gl-hw-info/build-in-modem" ];then
        modem_iface=$(get_modem_iface $bus)
    else
        return
    fi

    handle_bands $modem_iface
}

modem_AT_set_roaming()
{
    [ -f "/proc/gl-hw-info/build-in-modem" ] || return
    local bus=$(get_modem_bus)
    local modem_iface=$(get_modem_iface $bus)
    local roaming=`uci -q get network.$modem_iface.roaming`
    if [ "$roaming" = "0" ];then
        gl_modem -B $bus AT AT+QNWPREFCFG=\"roam_pref\",1
        gl_modem -B $bus AT AT+QNWCFG=\"data_roaming\",1
        gl_modem -B $bus AT AT+QCFG=\"roamservice\",1
    else
        gl_modem -B $bus AT AT+QNWPREFCFG=\"roam_pref\",255
        gl_modem -B $bus AT AT+QNWCFG=\"data_roaming\",0
        gl_modem -B $bus AT AT+QCFG=\"roamservice\",255
    fi

}

get_operator_type()
{
    local bus=$(get_modem_bus)
    local tmobiles="310160 310200 310210 310220 310230 310240 310250 310260 310270 310280 310300 310310 310330 310660 310800 310490 310530 310580 310590 310640 311500"

    for count in $(seq 1 3)
    do
        flag=`gl_modem -B $bus AT AT | grep 'OK'`
        [ "$flag" != "" ] && break
        [ $count -eq 3 ] && return
        sleep 1
    done

    local ret=""
    local operator=$(gl_modem -B $bus AT AT+COPS? | grep COPS | cut -d '"' -f 2)
    [ -n "$operator" ] || operator=$(gl_modem -B $bus AT AT+COPS? | grep COPS | cut -d '"' -f 2)
    if [ "$operator" = "T-Mobile" -o "$operator" = "Verizon" ]; then
        ret=$operator
        echo $ret
        return
    fi
    local imsi=$(gl_modem -B $bus AT AT+CIMI | tr -cd [0-9] | cut -b 1-6)
    local num=`echo $imsi | wc -c`
    if [ "$imsi" != "" ] && [ $num -gt 5 ] ;then
        for i in $(echo $tmobiles)
        do
            if [ "$i" = "$imsi" ]; then
                ret="T-Mobile"
            fi
        done

        local operator=`cat /etc/verizon.type | grep "$imsi"`
        if [ "$operator" != "" ];then
            ret="Verizon"
        fi

        [ "$ret" = "" ] && ret="normal"
    fi

    local sim_status1=$(gl_modem -B $bus AT AT+CPIN? | grep "+CPIN:" | cut -d ':' -f 2 | tr -cd "a-z0-9A-Z")
	sleep 1
    local sim_status2=$(gl_modem -B $bus AT AT+CPIN? | grep "+CPIN:" | cut -d ':' -f 2 | tr -cd "a-z0-9A-Z")
	sleep 1
    local sim_status3=$(gl_modem -B $bus AT AT+CPIN? | grep "+CPIN:" | cut -d ':' -f 2 | tr -cd "a-z0-9A-Z")
	sleep 1
    [ "$sim_status1" != "READY" ] && [ "$sim_status2" != "READY" ] && [ "$sim_status3" != "READY" ] && ret="-1"

    echo $ret
}

fix_tmobile_dial()
{
    local operator=$(get_operator_type)
    if [ -n "$operator" -a "$operator" = "T-Mobile" ] ; then
        local bus=$(get_modem_bus)
        pdp=$(gl_modem -B $bus AT 'AT$QCPRFMOD=PID:1' | grep OVRRIDEHOPDP | cut -d '"' -f 2)
        [ ! "$pdp" = "IPV4V6" ] && gl_modem -B $bus AT 'AT$QCPRFMOD=PID:1,OVRRIDEHOPDP:"IPV4V6"'
    fi
}

__check_modem_kmwan_network()
{
    local iface=`get_modem_iface`
    local tracks=""
    local track_ips=""
    local track_method=""

    tracks=$(uci -q get kmwan.$iface.tracks)
    if [ -z "$tracks" ]; then
        track_ips="8.8.8.8"
        track_method="ping"
    else
        track_method=$(echo $tracks | awk -F ',' '{print $1}')
        for iter in $tracks; do
            local ip=$(echo $tracks | awk -F ',' '{print $2}')
            track_ips="$ip $track_ips"
        done
    fi

    local proto=`uci get network.$iface.proto`
    local ifname=""

    local enable_ssl=`uci -q get kmwan.$iface.enable_ssl`
    if [ "$proto" != "3g" ];then
        if [ -f "/proc/gl-hw-info/pcie-bus" ];then
            ifname="rmnet_mhi0"
        else
            ifname="wwan0"
        fi
    else
        return 0
    fi

    for track_ip in $track_ips; do
        case "$track_method" in
            ping)
                /bin/ping -I $ifname -c 1 -W 1 $track_ip
                [ 0 -eq $? ] && return 0
            ;;
            httping)
                if [ "$enable_ssl" -eq "1" ]; then
                    httping -O $ifname -c 1 -t 1 -q "https://$track_ip" &> /dev/null
                else
                    httping -O $ifname -c 1 -t 1 -q "http://$track_ip" &> /dev/null
                fi
                [ 0 -eq $? ] && return 0
            ;;
        esac
    done

    return 1
}

__check_modem_network()
{
    local iface=`get_modem_iface`

    local track_ips=""
    track_ips=`uci -q get mwan3.$iface.track_ip`
    [ "$track_ips" = "" ] && track_ips="8.8.8.8"

    local track_method=""
    track_method=`uci -q get mwan3.$iface.track_method`
    [ "$track_method" = "" ] && track_method="ping"

    local proto=`uci get network.$iface.proto`
    local ifname=""

    local httping_ssl=`uci -q get mwan3.$iface.httping_ssl`
    if [ "$proto" != "3g" ];then
        if [ -f "/proc/gl-hw-info/pcie-bus" ];then
            ifname="rmnet_mhi0"
        else
            ifname="wwan0"
        fi
    else
        return 0
    fi

    for track_ip in $track_ips; do
        case "$track_method" in
            ping)
                /bin/ping -I $ifname -c 1 -W 1 $track_ip
                [ 0 -eq $? ] && return 0
            ;;
            httping)
                if [ "$httping_ssl" -eq 1 ]; then
                    httping -O $ifname -c 1 -t 1 -q "https://$track_ip" &> /dev/null
                else
                    httping -O $ifname -c 1 -t 1 -q "http://$track_ip" &> /dev/null
                fi
                [ 0 -eq $? ] && return 0
            ;;
        esac
    done

    return 1
}

check_ip()
{
    local bus=$(get_modem_bus)
    local modem_iface=$(get_modem_iface $bus)
    [ "$(uci -q get  network.$modem_iface.disabled)" = "0" ] || return
    local operator=$(get_operator_type)
    local apn_route=1
    if [ "$operator" = "Verizon" ]; then
        apn_route=3
	elif [ "$operator" = '' -o "$operator" = '-1' ];then
		return 0
    fi

    for count in $(seq 1 3); do
        module_ip=$(gl_modem -B $bus AT AT+CGPADDR | grep "+CGPADDR: $apn_route" | grep -v '0.0.0.0')
        [ -n "$module_ip" ] && break
        sleep 1
    done

    local interface_ip
    # interface_ip=$(ifconfig rmnet_mhi0 | grep inet | sed -n '1p'|awk '{print $2}'|awk -F ':' '{print $2}')
    if [ -n "$(ubus list | grep $modem_iface)" ]; then
        interface_ip=$(ubus call network.interface.${modem_iface}_4 status | jsonfilter -e '@["ipv4-address"][0].address')
        [ -z "$interface_ip" ] && interface_ip=$(ubus call network.interface.${modem_iface} status | jsonfilter -e '@["ipv4-address"][0].address')
    fi
    if [ -n "$module_ip" -a -n "$interface_ip" ]; then
        if [ -z "$(echo $module_ip | grep $interface_ip)" ]; then
            #local status=`cat /var/run/mwan3/iface_state/modem_0001_4`
            local flag=0
            for i in $(seq 1 3)
            do
                if [ ! -f "/proc/gl-kmwan/status" ];then
                    if __check_modem_network; then
                        flag=1
                        break
                    fi
                else
                    if __check_modem_kmwan_network; then
                        flag=1
                        break
                    fi
                fi
            done
            if [ 1 -eq $flag ];then
                return
            fi
            logger "modem ip different, now regain ip ..."
            Enable=`uci -q get passthrough.passthrough.enable`
            if [ "$Enable" = "1" ];then
                local value=`date +%s`
                uci set network.$modem_iface.date='$value'
                uci commit network

                /etc/init.d/network reload
                exit
            fi

            local device=$(ubus call network.interface.${modem_iface} status | jsonfilter -e @.l3_device)
            [ -n "$device" ] && ip addr del $(ip addr show | grep $interface_ip | awk -F ' ' '{print $2}') dev $device 2>/dev/null
            #kill -9 $(pgrep -f 'udhcpc') 2>/dev/null
            local proto=`uci get network.$modem_iface.proto`
            local ifname=""

            if [ "$proto" != "3g" ];then
                if [ -f "/proc/gl-hw-info/pcie-bus" ];then
                    ifname="rmnet_mhi0"
                else
                    ifname="wwan0"
                fi
            fi

            if [ "$ifname" != "" ];then
                local pid=`ps -w | grep udhcpc | grep "$ifname" | awk '{print $1}'`
                kill -9 $pid
            else
                local pid=`ps -w | grep udhcpc | grep rmnet_mhi0 | awk '{print $1}'`
                kill -9 $pid
            fi
        fi
    fi
}

generate_mwan3_config()
{
    local bus=$(get_modem_bus)
    local modem_iface=$(get_modem_iface $bus)
    local metric="4"
    local secondwan_ret=$(uci -q get mwan3.secondwan)
    if [ -n "$secondwan_ret" ]; then
        metric="5"
    fi
    uci set mwan3.$modem_iface='interface'
    uci set mwan3.$modem_iface.enabled='1'
    uci set mwan3.$modem_iface.family='ipv4'
    uci set mwan3.$modem_iface.reliability='1'
    uci set mwan3.$modem_iface.count='1'
    uci set mwan3.$modem_iface.timeout='2'
    uci set mwan3.$modem_iface.interval='5'
    uci set mwan3.$modem_iface.down='3'
    uci set mwan3.$modem_iface.up='8'
    track_ip_list=$(uci -q get glconfig.general.track_ip)
    uci -q delete mwan3.${modem_iface}.track_ip
    for ip in $track_ip_list; do
        uci add_list mwan3.${modem_iface}.track_ip="$ip"
    done

    uci set mwan3.${modem_iface}_6='interface'
    uci set mwan3.${modem_iface}_6.enabled='1'
    uci set mwan3.${modem_iface}_6.family='ipv6'
    uci set mwan3.${modem_iface}_6.reliability='1'
    uci set mwan3.${modem_iface}_6.count='1'
    uci set mwan3.${modem_iface}_6.timeout='2'
    uci set mwan3.${modem_iface}_6.interval='5'
    uci set mwan3.${modem_iface}_6.down='3'
    uci set mwan3.${modem_iface}_6.up='8'
    track_ipv6_list=$(uci -q get glconfig.general.track_ipv6)
    uci -q delete mwan3.${modem_iface}_6.track_ip
    for ipv6_addr in $track_ipv6_list; do
        uci add_list mwan3.${modem_iface}_6.track_ip="$ipv6_addr"
    done

    uci set mwan3.${modem_iface}_only='member'
    uci set mwan3.${modem_iface}_only.interface="$modem_iface"
    uci set mwan3.${modem_iface}_only.metric="$metric"
    uci set mwan3.${modem_iface}_only.weight='3'
    uci set mwan3.${modem_iface}_balance='member'
    uci set mwan3.${modem_iface}_balance.interface="$modem_iface"
    uci set mwan3.${modem_iface}_balance.metric='1'
    uci set mwan3.${modem_iface}_balance.weight='3'

    uci set mwan3.${modem_iface}_6_only='member'
    uci set mwan3.${modem_iface}_6_only.interface="${modem_iface}_6"
    uci set mwan3.${modem_iface}_6_only.metric="$metric"
    uci set mwan3.${modem_iface}_6_only.weight='3'
    uci set mwan3.${modem_iface}_6_balance='member'
    uci set mwan3.${modem_iface}_6_balance.interface="${modem_iface}_6"
    uci set mwan3.${modem_iface}_6_balance.metric='1'
    uci set mwan3.${modem_iface}_6_balance.weight='3'

    local mwan3_mode=$(uci -q get gl_mwan3.mwan3.mode)
    if [ "$mwan3_mode" = "0" ]; then
        [ -n "$(uci -q get mwan3.default_poli.use_member | grep modem)" ] || uci add_list mwan3.default_poli.use_member="${modem_iface}_only"
        [ -n "$(uci -q get mwan3.default_poli_v6.use_member | grep modem)" ] || uci add_list mwan3.default_poli_v6.use_member="${modem_iface}_6_only"
    elif [ "$mwan3_mode" = "1" ]; then
        [ -n "$(uci -q get mwan3.default_poli.use_member | grep modem)" ] || uci add_list mwan3.default_poli.use_member="${modem_iface}_balance"
        [ -n "$(uci -q get mwan3.default_poli_v6.use_member | grep modem)" ] || uci add_list mwan3.default_poli_v6.use_member="${modem_iface}_6_balance"
    fi
    uci commit mwan3
}

generate_kmwan_config()
{
    local bus=$(get_modem_bus)
    local modem_iface=$(get_modem_iface $bus)
    local metric="4"
    local secondwan_ret=$(uci -q get kmwan.secondwan)
    if [ -n "$secondwan_ret" ]; then
        metric="5"
    fi

    local tracks_arr=$(uci -q get kmwan.$modem_iface.tracks)
    local track_method=""
    if [ -z "$tracks_arr" ]; then
        track_method="ping"
    else
        track_method=$(echo $tracks_arr | awk -F ',' '{print $1}')
    fi

    uci set kmwan.$modem_iface='member'
    uci set kmwan.$modem_iface.disabled='0'
    uci set kmwan.$modem_iface.addr_type='4'
    uci set kmwan.$modem_iface.metric="$metric"
    uci set kmwan.$modem_iface.track_mode='passive'
    uci set kmwan.$modem_iface.weight='1'
    uci set kmwan.$modem_iface.interface="$modem_iface"

    track_ip_list=$(uci -q get glconfig.general.track_ip)
    uci -q delete kmwan.${modem_iface}.tracks
    for ip in $track_ip_list; do
        uci add_list kmwan.${modem_iface}.tracks="${track_method},$ip"
    done

    tracks_arr=$(uci -q get kmwan.${modem_iface}_6.tracks)
    track_method=""
    if [ -z "$tracks_arr" ]; then
        track_method="ping"
    else
        track_method=$(echo $tracks_arr | awk -F ',' '{print $1}')
    fi

    uci set kmwan.${modem_iface}_6='member'
    uci set kmwan.${modem_iface}_6.disabled='0'
    uci set kmwan.${modem_iface}_6.addr_type='6'
    uci set kmwan.${modem_iface}_6.metric="$metric"
    uci set kmwan.${modem_iface}_6.track_mode='passive'
    uci set kmwan.${modem_iface}_6.weight='1'
    uci set kmwan.${modem_iface}_6.interface="${modem_iface}_6"

    track_ipv6_list=$(uci -q get glconfig.general.track_ipv6)
    uci -q delete kmwan.${modem_iface}_6.tracks
    for ipv6_addr in $track_ipv6_list; do
        uci add_list kmwan.${modem_iface}_6.tracks="${track_method},$ipv6_addr"
    done

    uci commit kmwan
}

modem_AT_lock_cell_tower()
{
    local bus=`get_modem_bus`

    local slot=''
    local sim=`cat /proc/gl-hw-info/sim`
    if [ "$sim" = "dual" ];then
        slot=`gl_modem -B $bus AT AT+QUIMSLOT? | grep "+QUIMSLOT:" | tr -cd "0-9"`
        if [ $slot != "1" ] || [ $slot != "2" ];then
            local iface=`get_modem_iface`
            slot=`cat /tmp/run/dual_sim/$iface/current_sim`
        fi
    fi

    local section=''
    if [ "$slot" = "" ];then
        section="tower_sim"
    else
        section="tower_sim${slot}"
    fi

    local network_type=`uci -q get glmodem.$section.network_type`
    local pci=''
    local freq=''
    local band=''
    local scs=''
    local mnc=''
    local mcc=''
    if [ "NR5G" = "$network_type" ];then
        pci=`uci -q get glmodem.$section.pci`
        freq=`uci -q get glmodem.$section.freq`
        band=`uci -q get glmodem.$section.band`
        scs=`uci -q get glmodem.$section.scs`

        local tmp=`gl_modem -B $bus AT AT+QNWLOCK=\"common/5g\" | grep "QNWLOCK"`
        local tmp_pci=`echo $tmp | awk -F "," '{print $2}'`
        local tmp_freq=`echo $tmp | awk -F "," '{print $3}'`
        local tmp_scs=`echo $tmp | awk -F "," '{print $4}'`
        local tmp_band=`echo $tmp | awk -F "," '{print $5}' | sed 's/[^0-9]//g'`

        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",NR5G\'
        if [ "$pci" = "$tmp_pci" ] && [ "$freq" = "$tmp_freq" ] && [ "$band" = "$tmp_band" ] && [ "$scs" = "$tmp_scs" ];then
            return 0
        fi
        eval gl_modem -B $bus SAT sp 'AT+QNWLOCK=\"common/5g\",$pci,$freq,$scs,$band'
    elif [ "LTE" = "$network_type" ];then
        pci=`uci -q get glmodem.$section.pci`
        freq=`uci -q get glmodem.$section.freq`

        local tmp=`gl_modem -B $bus AT AT+QNWLOCK=\"common/4g\" | grep "QNWLOCK"`
        local tmp_pci=`echo $tmp | awk -F "," '{print $4}' | sed 's/[^0-9]//g'`
        local tmp_freq=`echo $tmp | awk -F "," '{print $3}'`

        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"mode_pref\",LTE:NR5G\'
        eval gl_modem -B $bus AT \'AT+QNWPREFCFG=\"nr5g_disable_mode\",1\'
        if [ "$pci" = "$tmp_pci" ] && [ "$freq" = "$tmp_freq" ];then
            return 0
        fi
        eval gl_modem -B $bus SAT sp 'AT+QNWLOCK=\"common/4g\",1,$freq,$pci'
    else
        return 0
    fi

    #gl_modem -B $bus SAT sp AT+CFUN=0
    #gl_modem -B $bus SAT sp AT+CFUN=1

    sleep 5
}

check_apn()
{
    local name=`get_operator_type`
    local tmp=`echo $name | tr [A-Z] [a-z]`
    local apn=""

    if [ "$tmp" = "verizon" ] || [ "$tmp" = "visible" ];then
        apn="3"
    elif [ "$tmp" = "" ];then
        apn="0"
    elif [ "$tmp" = "-1" ];then
        apn="-1"
    else
        apn="1"
    fi

    echo $apn
}

modem_AT_set_apn()
{
    local bus=`get_modem_bus`
    local modem_iface=$(get_modem_iface $bus)

    local apns=`uci -q get network.$modem_iface.apns | sed 's/\[\|\]\|\,//g'`
    [ "$apns" = "" ] && return 0
    local i=0
    local apn=''
    for apn in $apns
    do
        apn=`echo $apn | sed 's/\"//g'`
        i=$((i+1))
        if [ "$apn" != "" ];then
            eval gl_modem -B $bus AT 'AT+CGDCONT=$i,\"IPV4V6\",\"$apn\"'
        else
            local apn_use=`uci -q get network.$modem_iface.apn`
            if [ "$apn_use" = "$i" ];then
                local dial_apn=`uci -q get network.$modem_iface.apn`
                eval gl_modem -B $bus AT 'AT+CGDCONT=$i,\"IPV4V6\",\"$dial_apn\"'
            fi
        fi
    done

    gl_modem -B $bus SAT sp AT+CFUN=0
    gl_modem -B $bus SAT sp AT+CFUN=1

    sleep 10
}

modem_check_cellular()
{
    local custom_apn="$2"

    local bus="$1"
    local code=`gl_modem -B $bus AT AT+CIMI | tr -cd "[0-9]" | cut -b 1-6`
    local cellular=`cat /etc/${custom_apn}.type | grep "$code"`

    if [ "$cellular" = "" ];then
        return 1
    else
        return 0
    fi
}

modem_custom_apn_handle()
{
    local iface="$1"
    [ -d "/tmp/run/dual_sim/${iface}" ] && mkdir -p "/tmp/run/dual_sim/${iface}"

    local disabled=`uci -q get network.modem_0001.disabled`
    [ "$disabled" = "1" ] && return 1

    local sw_pid=`ps -w | grep "switch_sim_slot" | grep -v grep`
    [ "$sw_pid" != "" ] && return 1

    local sim=`cat /tmp/run/dual_sim/${iface}/current_sim`
    if [ "$sim" != "1" ] && [ "$sim" != 2 ];then
        return 1
    fi

    local count=`cat /tmp/run/dual_sim/${iface}/count_sim${sim}`
    [ "$count" = "" ] && count=1
    [ $count -ge 6 ] && return 1

    local custom_apn=`uci -q get glmodem.global.custom_apn`
    [ "$custom_apn" = "" ] && return 1

    local bus=`get_modem_bus`
    if ! modem_check_cellular $bus $custom_apn;then
        return 1
    fi
    count=$((count+1))
    echo $count > /tmp/run/dual_sim/${iface}/count_sim${sim}

    [ -f "/var/run/switch-sim.lock" ] && return 1
    local apns=`uci -q get custom_apn.${custom_apn}.apns | sed 's/\[\|\]\|\,//g' | sed 's/\"//g'`
    local i=0
    local current_apn=`uci -q get network.${iface}.apn`
    local last=`echo "$apns" | awk '{print $NF}'`
    for apn in $apns
    do
        i=$((i+1))
        [ "$apn" = "$current_apn" ] && break
    done
    i=$((i+1))
    apn=`echo "$apns" | awk -v j=$i '{print $j}'`
    [ "$apn" = "" ] && apn=`echo "$apns" | awk '{print $NR}'`
    touch /var/run/switch-sim.lock
    uci set network.${iface}.apn="$apn"
    uci set glmodem.network_sim${sim}.apn="$apn"
    uci commit network
    uci commit glmodem
    /etc/init.d/network reload
    rm /var/run/switch-sim.lock

    return 0
}

modem_net_monitor()
{
    [ ! -f "/proc/gl-hw-info/build-in-modem" ] && exit

    local modem_iface=`get_modem_iface`

    local pin=`uci -q get network.$modem_iface.pincode`
    [ "$pin" != "" ] && exit

    local disabled=`uci -q get network.$modem_iface.disabled`
    [ "$disabled" = 1 ] && exit

    local current_sim=`cat /var/run/dual_sim/$modem_iface/current_sim`
    local sim1_apn_poll=`uci -q get glmodem.global.sim1_apn_polling`
    local sim2_apn_poll=`uci -q get glmodem.global.sim2_apn_polling`
    [ "$current_sim" = "1" ] && [ "$sim1_apn_poll" = "0" ] && exit
    [ "$current_sim" = "2" ] && [ "$sim2_apn_poll" = "0" ] && exit

    if [ -n "$(ubus list | grep $modem_iface)" ]; then
        local interface_ip=$(ubus call network.interface.${modem_iface}_4 status | jsonfilter -e '@["ipv4-address"][0].address')
        [ -z "$interface_ip" ] && interface_ip=$(ubus call network.interface.${modem_iface} status | jsonfilter -e '@["ipv4-address"][0].address')

        if [ "$interface_ip" = "" ];then
            if modem_custom_apn_handle $modem_iface;then
                exit
            fi

            ubus call network.interface.$modem_iface down
            sleep 2
            ubus call network.interface.$modem_iface up

            return
        fi
    fi

    if [ -f "/proc/gl-hw-info/sim" ] && [ `cat /proc/gl-hw-info/sim` = "dual" ];then
        echo 0 > /tmp/run/dual_sim/${modem_iface}/count_sim1
        echo 0 > /tmp/run/dual_sim/${modem_iface}/count_sim2
    fi
}
