#!/bin/sh

. /lib/functions.sh
. /lib/functions/modem.sh
. /usr/share/libubox/jshn.sh

get_model() {
	local model=`uci get board_special.hardware.model 2>/dev/null`
	if [ -z "$model" ];then
		model=`cat /proc/gl-hw-info/model`
	fi
	echo $model
}

get_wan() {
	local wan=`uci get board_special.hardware.wan 2>/dev/null`
	if [ -z "$wan" ];then
		wan=`cat /proc/gl-hw-info/wan`
	fi
	echo $wan
}

get_radio() {
	local radio=`uci get board_special.hardware.radio 2>/dev/null`
	if [ -z "$radio" ];then
		radio=`cat /proc/gl-hw-info/radio 2>/dev/null`
	fi
	echo $radio
}

get_country_code() {
	uci -q get board_special.hardware.country_code || cat /proc/gl-hw-info/country_code
}

reset_indicate_led_name() {
	local model=$(get_model)
	local led

	case "$model" in
		"ar150"|\
		"mifi"|\
		"ar300"|\
		"ar300m")
			led="/sys/class/leds/gl-${model}:green:lan"
			;;
		"x300b")
			led="/sys/class/leds/gl-${model}:green:wan"
			;;
		"mt300a"|\
		"mt300n"|\
		"mt300n-v2")
			led="/sys/class/leds/green:wan"
			;;
		"usb150")
			led="/sys/class/leds/gl-${model}:green:power"
			;;
		"ar750")
			led="/sys/class/leds/gl-$model:white:power"
			;;
		"ar750s"|\
		"x750")
			led="/sys/class/leds/gl-$model:green:power"
			;;
		"ap1300"|\
		"s1300"|\
		"b1300")
			led="/sys/class/leds/green:power"
			;;
		"b2200")
			led="/sys/class/leds/power_white_led"
			;;
		"x1200")
			led="/sys/class/leds/gl-${model}:green:power"
			;;
		"xe300")
			led="/sys/class/leds/gl-${model}:green:wan"
			;;
		"n300")
			led="/sys/class/leds/microuter-${model}:blue:power"
			;;
		"a1300"|\
		"s200")
			led="/sys/class/leds/gl-${model}:blue"
			;;
		"mv1000")
			led="/sys/class/leds/gl-mv1000:white:power"
			;;
		"ax1800"|\
		"axt1800")
			led="/sys/class/leds/blue_led"
			;;
		"mt2500")
			led="/sys/class/leds/blue:system"
			;;
		"mt1300"|\
		"mt6000"|\
		"mt3000")
			led="/sys/class/leds/blue:run"
			;;
		"xe3000"|\
		"x3000")
			led="/sys/class/leds/power/"
			;;
		"sft1200")
			led="use_i2c_control_blue_flash"
			;;
		*)
	esac

	echo $led
}


# Some models, such as MT1300/SFT1200/AXT1800, require a daemon to control the LED
turnon_led() {
	model=$(get_model)

	case "$model" in
		"ax1800" |\
		"axt1800" |\
		"mt1300" |\
		"mt2500" |\
		"s200" |\
		"sft1200" |\
		"a1300")
			uci set gl_led.global.led_daemon='1'
			uci commit gl_led
			;;
		"mt6000" |\
		"mt3000")
			uci set gl_led.global.led_daemon='1'
			uci commit gl_led
			echo 1 > /sys/class/leds/blue:run/brightness
			;;
		"x3000" |\
		"xe3000")
			uci set gl_led.global.led_daemon='1'
			uci commit gl_led
			/etc/init.d/led start
			/etc/init.d/led enable
			/etc/init.d/modem_signal start
			;;
		"ar750")
			echo 1 > /sys/class/leds/gl-ar750:white:power/brightness
			/etc/init.d/led start
			/etc/init.d/led enable
			;;
		"ar750s")
			echo 1 > /sys/class/leds/gl-ar750s:green:power/brightness
			echo "phy1tpt" > /sys/class/leds/gl-ar750s:green:wlan2g/trigger
			echo "phy0tpt" > /sys/class/leds/gl-ar750s:green:wlan5g/trigger
			;;
		"xe300")
			echo "phy0tpt" > /sys/class/leds/gl-xe300:green:wlan/trigger
			/etc/init.d/led start
			/etc/init.d/led enable
			;;
		"mv1000")
			uci set gl_led.global.led_daemon='1'
			uci commit gl_led
			echo 1 > /sys/class/leds/gl-mv1000:white:power/brightness
			echo "netdev" > /sys/class/leds/gl-mv1000:white:wan/trigger
			echo "wan" > /sys/class/leds/gl-mv1000:white:wan/device_name
			echo 1 > /sys/class/leds/gl-mv1000:white:wan/link
			echo 1 > /sys/class/leds/gl-mv1000:white:wan/rx
			echo 1 > /sys/class/leds/gl-mv1000:white:wan/tx
			;;
		"x750")
			echo 1 > /sys/class/leds/gl-x750:green:power/brightness
			echo "phy1tpt" > /sys/class/leds/gl-x750:green:wlan2g/trigger
			echo "phy0tpt" > /sys/class/leds/gl-x750:green:wlan5g/trigger
			/etc/init.d/led start
			/etc/init.d/led enable
			;;
		"ar300m")
			echo 1 > /sys/class/leds/gl-ar300m:green:power/brightness
			echo "switch0" > /sys/class/leds/gl-ar300m:green:lan/trigger
			echo "phy0tpt" > /sys/class/leds/gl-ar300m:red:wlan/trigger
			/etc/init.d/led start
			/etc/init.d/led enable
			;;
		"mt300n-v2")
			echo 1 > /sys/class/leds/green:power/brightness
			echo "switch0" > /sys/class/leds/green:wan/trigger
			echo "0x1" > /sys/class/leds/green:wan/port_mask
			echo "netdev" > /sys/class/leds/red:wlan/trigger
			echo "ra0" > /sys/class/leds/red:wlan/device_name
			echo 1 > /sys/class/leds/red:wlan/link
			echo 1 > /sys/class/leds/red:wlan/rx
			echo 1 > /sys/class/leds/red:wlan/tx
			;;
		*)
			/etc/init.d/led start
			/etc/init.d/led enable
			;;
	esac
}

# Some models, such as MT1300/SFT1200/AXT1800, require some special instructions to turn off the LED
turnoff_led() {
	model=$(get_model)

	case "$model" in
		"axt1800")
			echo none > /sys/class/leds/blue_led/trigger
			echo 0 > /sys/class/leds/blue_led/brightness
			echo none > /sys/class/leds/white_led/trigger
			echo 0 > /sys/class/leds/white_led/brightness
			;;
		"ax1800")
			gl_i2c_led off
			echo none > /sys/class/leds/blue_led/trigger
			echo 0 > /sys/class/leds/blue_led/brightness
			echo none > /sys/class/leds/white_led/trigger
			echo 0 > /sys/class/leds/white_led/brightness
			;;
		"mt1300")
			gl_i2c_led off
			echo none > /sys/class/leds/blue:run/trigger
			echo 0 > /sys/class/leds/blue:run/brightness
			echo none > /sys/class/leds/white:system/trigger
			echo 0 > /sys/class/leds/white:system/brightness
			;;
		"mt6000" |\
		"mt3000")
			echo none > /sys/class/leds/blue:run/trigger
			echo 0 > /sys/class/leds/blue:run/brightness
			echo none > /sys/class/leds/white:system/trigger
			echo 0 > /sys/class/leds/white:system/brightness
			;;
		"mt2500")
			echo none > /sys/class/leds/blue:system/trigger
			echo 0 > /sys/class/leds/blue:system/brightness
			echo none > /sys/class/leds/white:system/trigger
			echo 0 > /sys/class/leds/white:system/brightness
			echo none > /sys/class/leds/vpn/trigger
			echo 0 > /sys/class/leds/vpn/brightness
			;;
		"xe3000"|\
		"x3000")
			/etc/init.d/led stop
			/etc/init.d/led disable
			/etc/init.d/modem_signal stop
			for led in `ls /sys/class/leds/`
			do
				echo none > /sys/class/leds/$led/trigger
				echo 0 > /sys/class/leds/$led/brightness
			done
			;;
		"s200")
			echo none > /sys/class/leds/gl-s200:blue/trigger
			echo 0 > /sys/class/leds/gl-s200:blue/brightness
			echo none > /sys/class/leds/gl-s200:green/trigger
			echo 0 > /sys/class/leds/gl-s200:green/brightness
			cat /sys/class/leds/gl-s200:green/brightness | grep "0" 1>/dev/null || ubus call gl_ledd on_off '{"led_name":"nwk_led","mode":"off"}'
			cat /sys/class/leds/gl-s200:blue/brightness | grep "0" 1>/dev/null || ubus call gl_ledd on_off '{"led_name":"sys_led","mode":"off"}'
			;;
		"a1300")
			gl_i2c_led off
			echo none > /sys/class/leds/gl-a1300:blue/trigger
			echo 0 > /sys/class/leds/gl-a1300:blue/brightness
			echo none > /sys/class/leds/gl-a1300:white/trigger
			echo 0 > /sys/class/leds/gl-a1300:white/brightness
			;;
		"sft1200")
			gl_i2c_led off
			;;
		"s1300"|\
		"b1300")
			echo none > /sys/class/leds/green:power/trigger
			echo 0 > /sys/class/leds/green:power/brightness
			echo none > /sys/class/leds/green:wlan/trigger
			echo 0 > /sys/class/leds/green:wlan/brightness
			;;
		"ap1300")
			echo none > /sys/class/leds/green:power/trigger
			echo 0 > /sys/class/leds/green:power/brightness
			echo none > /sys/class/leds/green:wan/trigger
			echo 0 > /sys/class/leds/green:wan/brightness
			;;
		"x300b")
			/etc/init.d/led stop
			/etc/init.d/led disable
			echo none > /sys/class/leds/gl-x300b:green:lte/trigger
			echo 0 > /sys/class/leds/gl-x300b:green:lte/brightness
			echo none > /sys/class/leds/gl-x300b:green:wan/trigger
			echo 0 > /sys/class/leds/gl-x300b:green:wan/brightness
			echo none > /sys/class/leds/gl-x300b:green:wlan2g/trigger
			echo 0 > /sys/class/leds/gl-x300b:green:wlan2g/brightness
			;;
		"ar750")
			echo none > /sys/class/leds/gl-ar750:white:power/trigger
			echo 0 > /sys/class/leds/gl-ar750:white:power/brightness
			echo none > /sys/class/leds/gl-ar750:white:wlan2g/trigger
			echo 0 > /sys/class/leds/gl-ar750:white:wlan2g/brightness
			echo none > /sys/class/leds/gl-ar750:white:wlan5g/trigger
			echo 0 > /sys/class/leds/gl-ar750:white:wlan5g/brightness
			;;
		"ar750s")
			echo none > /sys/class/leds/gl-ar750s:green:power/trigger
			echo 0 > /sys/class/leds/gl-ar750s:green:power/brightness
			echo none > /sys/class/leds/gl-ar750s:green:wlan2g/trigger
			echo 0 > /sys/class/leds/gl-ar750s:green:wlan2g/brightness
			echo none > /sys/class/leds/gl-ar750s:green:wlan5g/trigger
			echo 0 > /sys/class/leds/gl-ar750s:green:wlan5g/brightness
			;;
		"xe300")
			echo none > /sys/class/leds/gl-xe300:green:lte/trigger
			echo 0 > /sys/class/leds/gl-xe300:green:lte/brightness
			echo none > /sys/class/leds/gl-xe300:green:wlan/trigger
			echo 0 > /sys/class/leds/gl-xe300:green:wlan/brightness
			echo none > /sys/class/leds/gl-xe300:green:wan/trigger
			echo 0 > /sys/class/leds/gl-xe300:green:wan/brightness
			echo none > /sys/class/leds/gl-xe300:green:lan/trigger
			echo 0 > /sys/class/leds/gl-xe300:green:lan/brightness
			;;
		"mv1000")
			echo none > /sys/class/leds/gl-mv1000:white:power/trigger
			echo 0 > /sys/class/leds/gl-mv1000:white:power/brightness
			echo none > /sys/class/leds/gl-mv1000:white:wan/trigger
			echo 0 > /sys/class/leds/gl-mv1000:white:wan/brightness
			echo none > /sys/class/leds/gl-mv1000:white:vpn/trigger
			echo 0 > /sys/class/leds/gl-mv1000:white:vpn/brightness
			;;
		"x750")
			echo none > /sys/class/leds/gl-x750:green:power/trigger
			echo 0 > /sys/class/leds/gl-x750:green:power/brightness
			echo none > /sys/class/leds/gl-x750:green:wan/trigger
			echo 0 > /sys/class/leds/gl-x750:green:wan/brightness
			echo none > /sys/class/leds/gl-x750:green:lte/trigger
			echo 0 > /sys/class/leds/gl-x750:green:lte/brightness
			echo none > /sys/class/leds/gl-x750:green:wlan2g/trigger
			echo 0 > /sys/class/leds/gl-x750:green:wlan2g/brightness
			echo none > /sys/class/leds/gl-x750:green:wlan5g/trigger
			echo 0 > /sys/class/leds/gl-x750:green:wlan5g/brightness
			;;
		"ar300m")
			echo none > /sys/class/leds/gl-ar300m:green:power/trigger
			echo 0 > /sys/class/leds/gl-ar300m:green:power/brightness
			echo none > /sys/class/leds/gl-ar300m:green:lan/trigger
			echo 0 > /sys/class/leds/gl-ar300m:green:lan/brightness
			echo none > /sys/class/leds/gl-ar300m:red:wlan/trigger
			echo 0 > /sys/class/leds/gl-ar300m:red:wlan/brightness
			;;
		"mt300n-v2")
			echo none > /sys/class/leds/green:power/trigger
			echo 0 > /sys/class/leds/green:power/brightness
			echo none > /sys/class/leds/green:wan/trigger
			echo 0 > /sys/class/leds/green:wan/brightness
			echo none > /sys/class/leds/red:wlan/trigger
			echo 0 > /sys/class/leds/red:wlan/brightness
			;;
		*)
			/etc/init.d/led stop
			/etc/init.d/led disable
			;;
	esac
}

online_led_display() {
	model=$(get_model)

	case "$model" in
		"ax1800")
			echo none > /sys/class/leds/blue_led/trigger
			echo 0 > /sys/class/leds/blue_led/brightness
			echo none > /sys/class/leds/white_led/trigger
			echo 0 > /sys/class/leds/white_led/brightness
			gl_i2c_led white daemon
			;;
		"axt1800")
			cat /sys/class/leds/blue_led/trigger | grep "\[none\]" 1>/dev/null || echo none > /sys/class/leds/blue_led/trigger
			echo 0 > /sys/class/leds/blue_led/brightness
			echo 1 > /sys/class/leds/white_led/brightness
			;;
		"mt1300")
			echo none > /sys/class/leds/blue:run/trigger
			echo 0 > /sys/class/leds/blue:run/brightness
			echo none > /sys/class/leds/white:system/trigger
			echo 0 > /sys/class/leds/white:system/brightness
			gl_i2c_led white daemon
			;;
		"mt6000" |\
		"mt3000")
			cat /sys/class/leds/blue:run/trigger | grep "\[none\]" 1>/dev/null || echo none > /sys/class/leds/blue:run/trigger
			echo 0 > /sys/class/leds/blue:run/brightness
			echo 1 > /sys/class/leds/white:system/brightness
			;;
		"x3000"|\
		"xe3000")
			echo 1 > /sys/class/leds/internet/brightness
			;;
		"mt2500")
			cat /sys/class/leds/blue:system/trigger | grep "\[none\]" 1>/dev/null || echo none > /sys/class/leds/blue:system/trigger
			echo 0 > /sys/class/leds/blue:system/brightness
			echo 1 > /sys/class/leds/white:system/brightness
			;;
		"a1300")
			echo none > /sys/class/leds/gl-a1300:blue/trigger
			echo 0 > /sys/class/leds/gl-a1300:blue/brightness
			echo none > /sys/class/leds/gl-a1300:white/trigger
			echo 0 > /sys/class/leds/gl-a1300:white/brightness
			gl_i2c_led white daemon
			;;
		"s200")
			cat /sys/class/leds/gl-s200:blue/trigger | grep "\[none\]" 1>/dev/null || ubus call gl_ledd on_off '{"led_name":"sys_led","mode":"off"}'
			cat /sys/class/leds/gl-s200:green/brightness | grep "1" 1>/dev/null || ubus call gl_ledd on_off '{"led_name":"nwk_led","mode":"on"}'
			;;
		"sft1200")
			gl_i2c_led white daemon
			;;
		*)
	esac
}


offline_led_display() {
	model=$(get_model)

	case "$model" in
		"ax1800")
			echo none > /sys/class/leds/blue_led/trigger
			echo 0 > /sys/class/leds/blue_led/brightness
			echo none > /sys/class/leds/white_led/trigger
			echo 0 > /sys/class/leds/white_led/brightness
			gl_i2c_led blue_breath daemon
			;;
		"axt1800")
			echo 0 > /sys/class/leds/white_led/brightness
			cat /sys/class/leds/blue_led/trigger | grep "\[timer\]" 1>/dev/null || echo timer > /sys/class/leds/blue_led/trigger
			;;
		"mt1300")
			echo none > /sys/class/leds/blue:run/trigger
			echo 0 > /sys/class/leds/blue:run/brightness
			echo none > /sys/class/leds/white:system/trigger
			echo 0 > /sys/class/leds/white:system/brightness
			gl_i2c_led blue_breath daemon
			;;
		"mt2500")
			echo 0 > /sys/class/leds/white:system/brightness
			cat /sys/class/leds/blue:system/trigger | grep "\[timer\]" 1>/dev/null || echo timer > /sys/class/leds/blue:system/trigger
			;;
		"mt6000" |\
		"mt3000")
			echo 0 > /sys/class/leds/white:system/brightness
			cat /sys/class/leds/blue:run/trigger | grep "\[timer\]" 1>/dev/null || echo timer > /sys/class/leds/blue:run/trigger
			;;
		"x3000"|\
		"xe3000")
			echo 0 > /sys/class/leds/internet/brightness
			;;
		"a1300")
			echo none > /sys/class/leds/gl-a1300:blue/trigger
			echo 0 > /sys/class/leds/gl-a1300:blue/brightness
			echo none > /sys/class/leds/gl-a1300:white/trigger
			echo 0 > /sys/class/leds/gl-a1300:white/brightness
			gl_i2c_led blue_breath daemon
			;;
		"s200")
			cat /sys/class/leds/gl-s200:blue/brightness | grep "0" 1>/dev/null || ubus call gl_ledd on_off '{"led_name":"sys_led","mode":"off"}'
			cat /sys/class/leds/gl-s200:green/trigger | grep "\[timer\]" 1>/dev/null || ubus call gl_ledd blink '{"led_name":"nwk_led","delay_on":"500","delay_off":"500"}'
			;;
		"sft1200")
			gl_i2c_led blue_breath daemon
			;;
		*)
	esac
}

set_i2c_led_brightness() {
	model=$(get_model)

	case "$model" in
		"sft1200" |\
		"ax1800")
			i2cset  -f -y 0 0x30 0x06 0x0a
			i2cset  -f -y 0 0x30 0x07 0x0a
			;;
		"mt1300" |\
		"a1300")
			i2cset  -f -y 0 0x30 0x06 0x3f
			i2cset  -f -y 0 0x30 0x07 0x7f
			;;
		*)
	esac
}

vpn_off_led_display(){
	model=$(get_model)

	case "$model" in
		"mt2500")
			echo none > /sys/class/leds/vpn/trigger
			echo 0 > /sys/class/leds/vpn/brightness
			;;
		"mv1000")
			echo none > /sys/class/leds/gl-mv1000:white:vpn/trigger
			echo 0 > /sys/class/leds/gl-mv1000:white:vpn/brightness
			;;
		*)
	esac	
}

vpn_online_led_display(){
	model=$(get_model)

	case "$model" in
		"mt2500")
			echo none > /sys/class/leds/vpn/trigger
			echo 1 > /sys/class/leds/vpn/brightness
			;;
		"mv1000")
			echo none > /sys/class/leds/gl-mv1000:white:vpn/trigger
			echo 1 > /sys/class/leds/gl-mv1000:white:vpn/brightness
			;;
		*)
	esac	
}

vpn_offline_led_display(){
	model=$(get_model)

	case "$model" in
		"mt2500")
			echo 0 > /sys/class/leds/vpn/brightness
			echo timer > /sys/class/leds/vpn/trigger
			;;
		"mv1000")
			echo 0 > /sys/class/leds/gl-mv1000:white:vpn/brightness
			echo timer > /sys/class/leds/gl-mv1000:white:vpn/trigger
			;;
		*)
	esac	
}

led_blinking() {
	model=$(get_model)

	case "$model" in
		"mt300n-v2")
			echo timer > /sys/class/leds/green:power/trigger
			echo 1000 > /sys/class/leds/green:power/delay_off
			usleep 500000
			echo timer > /sys/class/leds/green:lan/trigger
			echo 1000 > /sys/class/leds/green:lan/delay_off
			usleep 500000
			echo timer > /sys/class/leds/red:wlan/trigger
			echo 1000 > /sys/class/leds/red:wlan/delay_off
			;;
		"ar300m")
			echo timer > /sys/class/leds/gl-${model}:green:power/trigger
			echo 1000 > /sys/class/leds/gl-${model}:green:power/delay_off
			usleep 500000
			echo timer > /sys/class/leds/gl-${model}:green:lan/trigger
			echo 1000 > /sys/class/leds/gl-${model}:green:lan/delay_off
			usleep 500000
			echo timer > /sys/class/leds/gl-${model}:red:wlan/trigger
			echo 1000 > /sys/class/leds/gl-${model}:red:wlan/delay_off
		;;
		"ar750" |\
		"ar750s")
			echo timer > /sys/class/leds/gl-${model}:green:power/trigger
			echo 1000 > /sys/class/leds/gl-${model}:green:power/delay_off
			usleep 500000
			echo timer > /sys/class/leds/gl-${model}:green:wlan2g/trigger
			echo 1000 > /sys/class/leds/gl-${model}:green:wlan2g/delay_off
			usleep 500000
			echo timer > /sys/class/leds/gl-${model}:green:wlan5g/trigger
			echo 1000 > /sys/class/leds/gl-${model}:green:wlan5g/delay_off
		;;
		"x300b")
			echo timer >   /sys/class/leds/gl-${model}:green:lte/trigger
			echo 1000 >    /sys/class/leds/gl-${model}:green:lte/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/gl-${model}:green:wan/trigger
			echo 1000 >    /sys/class/leds/gl-${model}:green:wan/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/gl-${model}:green:wlan2g/trigger
			echo 1000 >    /sys/class/leds/gl-${model}:green:wlan2g/delay_off
		;;
		"x750")
			echo timer >   /sys/class/leds/gl-${model}:green:power/trigger
			echo 2000 >    /sys/class/leds/gl-${model}:green:power/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/gl-${model}:green:wan/trigger
			echo 2000 >    /sys/class/leds/gl-${model}:green:wan/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/gl-${model}:green:wlan5g/trigger
			echo 2000 >    /sys/class/leds/gl-${model}:green:wlan5g/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/gl-${model}:green:wlan2g/trigger
			echo 2000 >    /sys/class/leds/gl-${model}:green:wlan2g/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/gl-${model}:green:lte/trigger
			echo 2000 >    /sys/class/leds/gl-${model}:green:lte/delay_off
		;;
		"xe300")
			echo timer >   /sys/class/leds/gl-${model}:green:wan/trigger
			echo 1500 >    /sys/class/leds/gl-${model}:green:wan/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/gl-${model}:green:lan/trigger
			echo 1500 >    /sys/class/leds/gl-${model}:green:lan/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/gl-${model}:green:wlan/trigger
			echo 1500 >    /sys/class/leds/gl-${model}:green:wlan/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/gl-${model}:green:lte/trigger
			echo 1500 >    /sys/class/leds/gl-${model}:green:lte/delay_off
		;;
		"xe3000" |\
		"x3000")
			echo timer >   /sys/class/leds/internet/trigger
			echo 1000 >    /sys/class/leds/internet/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/wifi:2g/trigger
			echo 1000 >    /sys/class/leds/wifi:2g/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/wifi:5g/trigger
			echo 1000 >    /sys/class/leds/wifi:5g/delay_off
			;;
		"mt6000")
			echo timer >   /sys/class/leds/blue:run/trigger
			echo 500 >    /sys/class/leds/blue:run/delay_off
			usleep 500000
			echo timer >   /sys/class/leds/white:system/trigger
			echo 500 >    /sys/class/leds/white:system/delay_off
			;;
	*)
	esac
}

sysupgrade_led_display(){
	model=$(get_model)

	case "$model" in
		"sft1200" |\
		"mt1300" |\
		"a1300")
			/etc/init.d/gl_led stop
			gl_i2c_led blue_flash
			;;
		"axt1800")
			/etc/init.d/gl_led stop
			echo 0 > /sys/class/leds/white_led/brightness
			cat /sys/class/leds/blue_led/trigger | grep "\[timer\]" 1>/dev/null || echo timer > /sys/class/leds/blue_led/trigger
			;;
		"s200")
			/etc/init.d/gl_led stop
			ubus call gl_ledd on_off '{"led_name":"iot_led","mode":"off"}'
			/etc/init.d/gl_ledd stop
			echo 0 > /sys/class/leds/gl-s200:green/brightness
			cat /sys/class/leds/gl-s200:blue/trigger | grep "\[timer\]" 1>/dev/null || echo timer > /sys/class/leds/gl-s200:blue/trigger
			;;
		"mt300n-v2" |\
		"ar300m" |\
		"ar750" |\
		"xe300" |\
		"x750"  |\
		"x300b" |\
		"ar750s" |\
		"mt6000" |\
		"xe3000" |\
		"x3000")
			/etc/init.d/gl_led stop
			led_blinking
			;;
		"mv1000")
			echo timer > /sys/class/leds/gl-mv1000:white:power/trigger
			;;
		*)
	esac
}

led_trigger_faster() {
	[ -n "$1" ] || return 0

	sleep 3
	[ -e "$1/delay_on" ] && echo "250" > $1/delay_on
	[ -e "$1/delay_off" ] && echo "250" > $1/delay_off

	# sft1200 can only control the led by use i2c
	[ -n "`echo $1 | grep use_i2c_control`" ] && gl_i2c_led "${1##use_i2c_control_}" medium
}

led_trigger_fastest() {
	[ -n "$1" ] || return 0

	sleep 8
	[ -e "$1/delay_on" ] && echo "125" > $1/delay_on
	[ -e "$1/delay_off" ] && echo "125" > $1/delay_off

	# sft1200 can only control the led by use i2c
	[ -n "`echo $1 | grep use_i2c_control`" ]  && gl_i2c_led "${1##use_i2c_control_}" fast
}

oled_control(){
	local model=$(get_model)
	local program_exit
	case "$model" in
		"e750")
			if [ "$1" = "pressed" ];then
				/usr/bin/e750_button &
			elif [ "$1" = "released" ];then
				program_exit=`ps | grep e750_button | grep -v grep`
				[ -n "$program_exit" ] && {
					for pid in $(pgrep -f "e750_button")
					do
						kill -9 $pid
					done
				}
			fi
	;;
	esac
}

reset_btn_pressed() {
	local model=$(get_model)
	local led=$(reset_indicate_led_name)
	local all_led=''
	oled_control "pressed"

	[ -n "$led" ] || return 0

	led_trigger_faster $led &
	echo "$!" >> /tmp/led_trigger_pid
	led_trigger_fastest $led &
	echo "$!" >> /tmp/led_trigger_pid

	case "$model" in
		"ax1800" |\
		"axt1800")
			/etc/init.d/gl_led stop
			echo 0 > /sys/class/leds/white_led/brightness
			echo "timer" > $led/trigger
			;;
		"mt1300")
			/etc/init.d/gl_led stop
			echo 0 > /sys/class/leds/white:system/brightness
			echo "timer" > $led/trigger
			;;
		"mt2500" |\
		"mt6000" |\
		"mt3000")
			/etc/init.d/gl_led stop
			echo 0 > /sys/class/leds/white:system/brightness
			echo "timer" > $led/trigger
			;;
		"a1300")
			/etc/init.d/gl_led stop
			echo 0 > /sys/class/leds/gl-a1300:white/brightness
			echo "timer" > $led/trigger
			;;
		"s200")
			/etc/init.d/gl_led stop
			all_led=`uci -q get gl_led_cfg.global.all_led`
			if [ "$all_led" = "1" ];then
				ubus call gl_ledd blink '{"led_name":"sys_led","delay_on":"500","delay_off":"500"}'
			else
				echo "timer" > $led/trigger
			fi
			;;
		"sft1200")
			/etc/init.d/gl_led stop
			gl_i2c_led blue_flash normal
			;;
		*)
			echo "timer" > $led/trigger
			;;
	esac
}

reset_btn_released() {
	local model=$(get_model)
	local led=$(reset_indicate_led_name)
	local all_led=''
	oled_control "released"
	[ -n "$led" ] || return 0

	[ -e /tmp/led_trigger_pid ] && {
		cat /tmp/led_trigger_pid | xargs kill -9
		rm /tmp/led_trigger_pid
	}

	case "$model" in
		"e750")
			echo "none" > $led/trigger
			killall -17 e750-mcu
			;;
		"ax1800" |\
		"axt1800" |\
		"mt1300" |\
		"mt2500" |\
		"mt6000" |\
		"mt3000" |\
		"x300b" |\
		"b1300" |\
		"s1300" |\
		"ap1300" |\
		"a1300" |\
		"mv1000")
			echo "none" > $led/trigger
			/etc/init.d/gl_led start
			;;
		"s200")
			all_led=`uci -q get gl_led_cfg.global.all_led`
			if [ "$all_led" = "1" ];then
				ubus call gl_ledd on_off '{"led_name":"sys_led","mode":"off"}'
			else
				echo "none" > $led/trigger
			fi
			/etc/init.d/gl_led start
			;;
		"ar300m" |\
		"mt300n-v2" |\
		"sft1200" |\
		"x300b" |\
		"xe300" |\
		"ar750s")
			/etc/init.d/gl_led start
			;;
		*)
			echo "none" > $led/trigger
			echo 1 > $led/brightness
			;;
	esac
}

set_modem_cfun0() {
    if [ -e "/proc/gl-hw-info/build-in-modem" -a -n "$(ls /dev/ | grep -E 'ttyU|mhi_')" ]; then
        local ret
        local bus=$(get_modem_bus)
        local model=$(get_model)

        case "$model" in
        "x3000")
            for count in $(seq 1 3); do
                ret=$(gl_modem -B $bus SAT sp AT+CFUN=0 | grep "OK")
                [ -n "$ret" ] && logger "set modem cfun0 success" && break
                sleep 1
            done
            ;;
        "xe3000")
            for count in $(seq 1 3); do
                ret=$(gl_modem -B $bus SAT sp AT+CFUN=0 | grep "OK")
                [ -n "$ret" ] && logger "set modem cfun0 success" && break
                sleep 1
            done
            sleep 1
            gl_modem -B $bus SAT sp AT+QPOWD
            ;;
        esac
    fi
}

factory_reset() {
	local model=$(get_model)
	local led=$(reset_indicate_led_name)

	echo "FACTORY RESET" > /dev/console

	case "$model" in
		"s200")
			ubus call gl_ledd on_off '{"led_name":"nwk_led","mode":"off"}'
			ubus call gl_ledd blink '{"led_name":"sys_led","delay_on":"200","delay_off":"200"}'
			;;
		"e750")
			program_button_exit=`ps | grep e750_button | grep -v grep`
			[ -n "$program_button_exit" ] && {
				for pid in $(pgrep -f "e750_button")
				do
					kill -9 $pid
				done
			}

			sleep 1
			ubus call mcu system_reft {\"system\":\"reft\"}
			sleep 2
			/etc/init.d/mcu stop
			;;
		"x3000")
			set_modem_cfun0
			;;
		*)
			/etc/init.d/gl_led stop
			[ -e "$led/trigger" ] && echo "timer" > $led/trigger
			[ -e "$led/delay_on" ] && echo 200 > $led/delay_on
			[ -e "$led/delay_off" ] && echo 200 > $led/delay_off
			# sft1200 can only control the led by use i2c
			[ -n "`echo $led | grep use_i2c_control`" ] && gl_i2c_led "${1##use_i2c_control_}" medium
			;;
	esac

        [ -e "/etc/init.d/tailscale" ] && /etc/init.d/tailscale stop
        /sbin/firstboot -y;reboot
}

mv1000_reset_wireless() {
	local phy=''
	local i=0
	local mode=''

	while true
	do
		phy=`uci -q get wireless.@wifi-device[$i].phy`
		mode=`uci -q get wireless.@wifi-iface[$i].mode`
		if [ "$phy" = "phy" ];then
			i=$((i+1))
			continue
		elif [ "$phy" = "" ];then
			break
		fi

		if [ "$mode" = "sta" ];then
			uci set wireless.@wifi-device[$i].disabled='1'
			i=$((i+1))
			continue
		fi

		uci set wireless.@wifi-device[$i].disabled='0'
		uci set wireless.@wifi-iface[$i].disabled='0'
		i=$((i+1))
	done

	local dev=`uci -q get wireless.guest2g.device`
	if [ "$dev" != "" ];then
		uci set wireless.guest2g.disabled='1'
	fi
}

access_vpn_tap() {
	local vpnid path config profile
	vpnid="$(uci get glconfig.openvpn.clientid)"
	path="$(uci get ovpnclients.${vpnid}.path)"
	config="$(uci get ovpnclients.${vpnid}.defaultserver)"
	profile="$(echo ${path}/${config})"
	[ -n "$(cat $profile |grep dev| grep tap)" ] && return 0
	return 1
}

platform_network_restart() {
	local model=$(get_model)
    if [ "$model" = "ar750s" -o "$model" = "x1200" ];then
        /etc/init.d/network restart; swconfig dev switch0 set phy_reset
    elif [ "$model" = "mt1300" ];then
        ethtool -i eth0 1>/dev/null; /etc/init.d/network restart
    elif [ "$model" = "xe300" -o "$model" = "s200" ];then
        /etc/init.d/network restart;swconfig dev switch0 set reset
    elif [ "$model" = "a1300" -o "$model" = "b1300" -o "$model" = "s1300" -o "$model" = "ap1300" ];then
        etc/init.d/network restart
        swconfig dev switch0 set linkdown 1
        swconfig dev switch0 set linkdown 0
    else
        /etc/init.d/network restart
    fi
}

disconnect_lan_clients(){
	local model=$(get_model)

	if [ -e /sys/class/ieee80211 ]; then
		/sbin/wifi
	fi
	if [ -e /sys/class/net/ra0 ]; then
		iwpriv ra0 set DisConnectAllSta=1
		iwpriv ra1 set DisConnectAllSta=1
		if [ -e /sys/class/net/rax0 ]; then
			iwpriv rax0 set DisConnectAllSta=1
			iwpriv rax1 set DisConnectAllSta=1
		fi
	fi

	ports=$(uci get network.@device[0].ports)
	if [ -n "$ports" ]; then
		for port in $ports; do
			if [ "${port:0:3}" = "eth" ]; then
				ip link set $port down
				ip link set $port up
			fi
		done
	fi
	case "$model" in
		"ar150"|\
		"mifi"|\
		"ar750"|\
		"ar300m"|\
		"x750"|\
		"e750"|\
		"x300b"|\
		"xe300"|\
		"s200"|\
		"ar750s")
			swconfig dev switch0 set reset
			;;
		"a1300"|\
		"b1300"|\
		"s1300"|\
		"ap1300")
			swconfig dev switch0 set linkdown 1
			sleep 1
			swconfig dev switch0 set linkdown 0
			;;
		"mt300n-v2")
			swconfig dev switch0 port 1 set disable 1
			swconfig dev switch0 set apply 1
			sleep 1
			swconfig dev switch0 port 1 set disable 0
			swconfig dev switch0 set apply 1
			;;
		"sft1200"|\
		"sf1200")
			/etc/init.d/network restart
			;;
	esac
}

reset_network() {
    local model=$(get_model)
    if [ -f "/tmp/lock/procd_reset_network.lock" ];then
	ubus call mcu system_renw {\"system\":\"renw\"}
	logger "the reset button is pressed too fast,reset network lock"
    else
	touch /tmp/lock/procd_reset_network.lock
	local osver

	echo "Now resetting network" > /dev/console

	if [ -f /etc/board.json ];
	then
		. /etc/os-release
		osver=$(echo $VERSION_ID | grep -o '^[0-9]*')

		json_init
		json_load "$(cat /etc/board.json)"

		json_select network

		json_is_a lan object
		if [ $? -eq 0 ];
		then
			json_select lan
			json_get_vars protocol ifname
			json_select ..

			uci set network.lan.proto="$protocol"
			if [ $osver -gt 20 ];
			then
				uci delete network.@device[0].ports
				for port in $(cat /proc/gl-hw-info/lan);
				do
					uci add_list network.@device[0].ports="$port"
				done
			else
				uci set network.lan.ifname="$ifname"
			fi
		else
			uci delete network.lan
		fi

		json_is_a wan object
		if [ $? -eq 0 ];
		then
			json_select wan
			json_get_vars protocol ifname device
			json_select ..

			uci set network.wan.proto="$protocol"

			[ $osver -gt 20 ] && uci set network.wan.device="$device" || uci set network.wan.ifname="$ifname"
		else
			if [ "$model" != "e750" ]; then
				uci delete network.wan
			fi
		fi
	else
		local wan_eth="$(cat /proc/gl-hw-info/wan)"
		local lan_eth="$(cat /proc/gl-hw-info/lan)"

		uci set network.wan.ifname="$wan_eth"
		uci set network.wan.proto="dhcp"
		uci set network.lan.proto="static"
		uci set network.lan.ifname="$lan_eth"
	fi

	case "$model" in
		"ar150"|\
		"s200"|\
		"mifi"|\
		"ar300m"|\
		"x300b"|\
		"xe300"|\
		"mt300a"|\
		"mt300n"|\
		"n300"|\
		"usb150")
			uci set wireless.radio0.disabled='0'
			uci set wireless.@wifi-iface[0].disabled='0'
			uci set wireless.guest2g.disabled='1'
			;;
		"mt300n-v2")
			uci set wireless.radio0.disabled='0'
			uci set wireless.@wifi-iface[0].disabled='0'
			uci set wireless.guest2g.disabled='1'

			uci set system.led_wifi_led.dev='ra0'
			/etc/init.d/led restart
			;;
		"mv1000")
			mv1000_reset_wireless
			;;
		*)
			uci set wireless.radio0.disabled='0'
			uci set wireless.radio1.disabled='0'
			uci set wireless.@wifi-iface[0].disabled='0'
			uci set wireless.@wifi-iface[1].disabled='0'
			uci set wireless.guest2g.disabled='1'
			uci set wireless.guest5g.disabled='1'
			;;
	esac

	uci -q delete network.wan.disabled
	uci -q delete network.wan.peerdns
	uci -q delete network.lan.macaddr

	default_macaddr=$(uci get network.lan.default_macaddr)
	[ -n "$default_macaddr" ] && uci set network.lan.macaddr=$default_macaddr

	uci -q delete network.tethering.dns
	uci -q delete network.modem.dns

	uci set dhcp.lan.ignore='0'

	if [ "$model" = "e750" ]; then
		ubus call mcu system_renw {\"system\":\"renw\"}
		uci set glconfig.general.wan2lan='1'
	else
		uci set glconfig.general.wan2lan='0'
	fi

	local passthrough=`uci -q get passthrough.passthrough.enable`
	if [ "$passthrough" = "1" ];then
		uci -q del firewall.passthrough
		uci commit firewall
		/etc/init.d/firewall restart

		uci set passthrough.passthrough.enable='0'
	fi

	local lan2wan=`uci -q get glconfig.general.lan2wan`
	if [ "$lan2wan" = "1" ];then
		uci set glconfig.general.lan2wan='0'
		uci -q delete network.secondwan.device
		uci -q delete network.secondwan.disabled
	fi

	uci commit

	[ -d "/etc/gl-reset-network.d" ] && {
		for a in $(ls /etc/gl-reset-network.d); do
			. /etc/gl-reset-network.d/$a
		done
	}
	if [ "$model" = "a1300" -o "$model" = "b1300" -o "$model" = "s1300" -o "$model" = "ap1300" ]; then
		sleep 5
	fi
	/etc/init.d/gl_ipv6 reload
	/etc/init.d/network restart
	/etc/init.d/sysctl restart
	/etc/init.d/dnsmasq enable
	/etc/init.d/dnsmasq restart
	/etc/init.d/repeater restart

	if [ "$model" = "ar150" -o "$model" = "mifi" -o "$model" = "ar750" -o "$model" = "ar300m" -o "$model" = "x750" -o "$model" = "e750" \
		-o "$model" = "x300b" -o "$model" = "xe300" -o "$model" = "s200" -o "$model" = "ar750s" ];then
			swconfig dev switch0 set reset
	elif [ "$model" = "a1300" -o "$model" = "b1300" -o "$model" = "s1300" -o "$model" = "ap1300" ]; then
			swconfig dev switch0 set linkdown 1
			sleep 2
			swconfig dev switch0 set linkdown 0
	fi
	if [ "$model" = "ar150" -o "$model" = "mifi" -o "$model" = "ar750" -o "$model" = "ar300m" -o "$model" = "x750"  \
		-o "$model" = "x300b" -o "$model" = "xe300" ];then
			/etc/init.d/led  reload
	fi

	[ "$(uci -q get zerotier.gl.enabled)" = "1" ] && /etc/init.d/zerotier restart
	rm -rf /tmp/lock/procd_reset_network.lock
    fi
}

dnsmasq_set_resolvfile()
{
	local target=$1
	[ -z $target ] && return
	[ -f /tmp/"$target" ] && {
		uci set dhcp.@dnsmasq[0].resolvfile=/tmp/"$target"
		uci commit dhcp
		return
	}
	[ -f /tmp/resolv.conf.d/"$target" ] && {
		uci set dhcp.@dnsmasq[0].resolvfile=/tmp/resolv.conf.d/"$target"
		uci commit dhcp
		return
	}
}

usb_driver_crash_avoidance_scheme()
{
	local model=$(get_model)
	local action=$1
	if [ "$model" = a1300 -o "$model" = b1300 -o "$model" = s1300 -o "$model" = ap1300 ];
	then
         if [ "$action" = offline ];then
                rmmod /lib/modules/5.4.179/xhci-plat-hcd.ko
                insmod /lib/modules/5.4.179/xhci-plat-hcd.ko
         fi

	fi
}

remount_ubifs()
{
	local model=$(get_model)
	if [ "$model" = a1300 ]; then
		mount -o remount,sync,assert=report /overlay/
	fi
}

fan_init()
{
    local model=$(get_model)
    local temperature=75
    local sysfs="/sys/devices/virtual/thermal/thermal_zone0/temp"
    local div=1

    case "$model" in
	mt6000 |\
	mt3000)
		div=1000
		temperature=76
		;;
	xe3000 |\
	x3000)
		div=1000
		;;
    *)
        ;;
    esac

    uci rename glfan.@globals[0]="globals"
    uci set glfan.@globals[0].temperature="$temperature"
    uci set glfan.@globals[0].warn_temperature="$temperature"
    uci set glfan.@globals[0].sysfs="$sysfs"
    uci set glfan.@globals[0].div="$div"
    uci commit glfan
}

fix_ipq40xx_wan_vlan()
{
	if [ -f /proc/sys/net/edma/default_wan_tag ]; then
		if [ -z "$(grep "ports '5 0'" /etc/config/network)" ]; then
			uci add network switch_vlan
			uci set network.@switch_vlan[-1].device='switch0'
			uci set network.@switch_vlan[-1].vlan='2'
			uci set network.@switch_vlan[-1].ports='5 0'
			uci commit network
		fi
	fi
}

fix_ax1800_upgrade_url()
{
	local model=$(get_model)
	if [ "$model" = ax1800 ]; then
		if [ "$(uci -q get upgrade.general.url)" != "https://fw.gl-inet.com/firmware/ax1800/v4" ]; then
			uci set upgrade.general.url='https://fw.gl-inet.com/firmware/ax1800/v4'
			uci commit upgrade
		fi
	fi
}

mwan3_init() {
        local model=$(get_model)
        local member
        if [ "$model" = s200 -o "$model" = x300b ]; then
           uci -q delete mwan3.tethering
           uci -q delete mwan3.tethering_only
           uci -q delete mwan3.tethering_balance
           uci -q delete mwan3.tethering6
           uci -q delete mwan3.tethering6_only
           uci -q delete mwan3.tethering6_balance
           uci commit mwan3
           member="wan wwan wan6 wwan6"
        else
           member="wan wwan tethering wan6 wwan6 tethering6"
        fi
        echo $member
}

turnoff_iot_led() {
	model=$(get_model)

	case "$model" in
		"s200")
			ubus call gl_ledd all_status '{"all_led_status":"off"}'
			;;
		*)
	esac

}

turnon_iot_led() {
	model=$(get_model)

	case "$model" in
		"s200")
			ubus call gl_ledd all_status '{"all_led_status":"on"}'
			;;
		*)
	esac
}

set_nginx_thread() {
	model=$(get_model)

	case "$model" in
		"sf1200" |\
		"sft1200" |\
		"x750" |\
		"ar750" |\
		"ar750s" |\
		"mt300n-v2"|\
		"x300b" |\
		"xe300" |\
		"e750" |\
		"ar300m")
			sed 's/worker_processes.*;/worker_processes 2;/g' -i /etc/nginx/nginx.conf
			;;
		*)
	esac
}

set_hnat_by_default() {
	model=$(get_model)

	case "$model" in
		"mt1300")
			uci set firewall.@defaults[0].flow_offloading='1'
			uci set firewall.@defaults[0].flow_offloading_hw='1'
			uci commit  firewall
			;;
		*)
	esac
}

set_mcu_uart_dev_by_default() {
	model=$(get_model)

	case "$model" in
               "e750")
		       dev=`cut -f 1 -d , /proc/gl-hw-info/mcu 2>/dev/null`
		       baudrate=`cut -f 2 -d , /proc/gl-hw-info/mcu 2>/dev/null`
		       oled=`cut -f 2 -d , /proc/gl-hw-info/oled 2>/dev/null`
		       if [ -n "$dev" -a -n "$baudrate" -a -n "$oled" ];then
			       uci set glconfig.mcu=service
			       uci set glconfig.mcu.dev="$dev"
			       uci set glconfig.mcu.baudrate="$baudrate"
			       uci set glconfig.mcu.oled="$oled"
			       uci set glconfig.mcu.printk="0"
			       uci commit glconfig
		       fi
		       ;;

		*)
			dev=`cut -f 1 -d , /proc/gl-hw-info/mcu 2>/dev/null`
			baudrate=`cut -f 2 -d , /proc/gl-hw-info/mcu 2>/dev/null`
			if [ -n "$dev" -a -n "$baudrate" ];then
				uci set glconfig.mcu=service
				uci set glconfig.mcu.dev="$dev"
				uci set glconfig.mcu.baudrate="$baudrate"
				uci commit glconfig
			fi
			;;
	esac
}

sysupgrade_mcu_screen_display(){
	model=$(get_model)
	case "$model" in
		"e750")
			ubus call mcu system_update
			sleep 2
			/etc/init.d/mcu stop
		;;
	esac
}

# return 0 means has secondwan
has_secondwan() {
	model=$(get_model)

	case "$model" in
		"mt6000" |\
		"xe3000")
			return 0
		;;
		*)
			return 1
		;;
	esac
}

fix_ovpn_dns_leak(){
	local kill_switch_en="$(uci -q get vpnpolicy.global.kill_switch)"
	local ovpnlient_disable="$(uci -q get network.ovpnclient.disabled)"
	local wan_access="$(uci -q get vpnpolicy.global.wan_access)"
	uci set firewall.block_dns.enabled='0'
	# 开启killswich或vpn客户端开启的情况下，接口down掉，始终阻止dns查询
	if [ "$wan_access" = 0 ]; then
		if [ "$kill_switch_en" = 1 -o "$ovpnlient_disable" = 0 ]; then
			uci set firewall.block_dns.enabled='1'
		fi
	fi
	uci commit firewall
}

remove_ovpn_server_route(){
	SERVER_IPS=$(cat /tmp/run/ovpn_resolved_ip | sort | uniq)
	for SERVER_IP in $SERVER_IPS; do
		if [ -n "$SERVER_IP" ]; then
			ip route del $SERVER_IP
		fi
	done
}

remove_wg_server_route(){
	SERVER_IPS=$(cat /tmp/run/wg_resolved_ip | sort | uniq)
	for SERVER_IP in $SERVER_IPS; do
		if [ -n "$SERVER_IP" ]; then
			ip route del $SERVER_IP
		fi
	done
}

create_reload_service()
{
    local name="$(basename $1)"
    if [ $GL_SERVICE_QUEUE = "1" ];then
        mkdir -p /var/run/gl_reload_service
        echo "$1" >/var/run/gl_reload_service/"$name"
    else
        $1 reload
    fi
}

create_restart_service()
{
    local name="$(basename $1)"
    if [ $GL_SERVICE_QUEUE = "1" ];then
        mkdir -p /var/run/gl_restart_service
        echo "$1" >/var/run/gl_restart_service/"$name"
    else
        $1 restart
    fi
}

set_tuning_switch()
{
	local band=$1
	model=$(get_model)

	case "$model" in
		"e750")
			if [ $band = "1" -o $band = "2" -o $band = "7" -o $band = "8" \
			  -o $band = "25" -o $band = "38" -o $band = "39" -o $band = "40" -o $band = "41" ]; then
				echo 0 > /sys/class/gpio/gpio13/value
				echo 0 > /sys/class/gpio/gpio14/value
				echo 0 > /sys/class/gpio/gpio17/value
			elif [ -o $band = "3" -o $band = "4" $band = "5" -o $band = "20" -o $band = "26" -o $band = "66" ]; then
				echo 0 > /sys/class/gpio/gpio13/value
				echo 1 > /sys/class/gpio/gpio14/value
				echo 0 > /sys/class/gpio/gpio17/value
			elif [ $band = "12" -o $band = "13" -o $band = "17" -o $band = "28" ]; then
				echo 1 > /sys/class/gpio/gpio13/value
				echo 0 > /sys/class/gpio/gpio14/value
				echo 0 > /sys/class/gpio/gpio17/value
			elif [ $band = "71" ]; then
				echo 1 > /sys/class/gpio/gpio13/value
				echo 1 > /sys/class/gpio/gpio14/value
				echo 0 > /sys/class/gpio/gpio17/value
			fi
			;;
		*)
	esac
}

wan2lan_init()
{
	model=$(get_model)

	case "$model" in
		"e750")
			uci set glconfig.general.wan2lan='1'

			uci set network.wan=interface
			uci set network.wan.proto='dhcp'
			uci set network.wan.force_link='0'
			uci set network.wan.ipv6='0'

			uci set network.wan6=interface
			uci set network.wan6.proto='dhcpv6'
			uci set network.wan6.ifname='@wan'
			uci set network.wan6.disabled='1'
			uci commit
			;;
		*)
    esac
}

generate_default_ssid()
{
    local band="$1"
    local mac="$2"
    model=$(get_model | awk '{ print toupper($1) }')

    local ssid="GL-$model-$mac"

    if [ "$model" != "E750" ]; then
        echo "$band" | grep -q 5 && {
		ssid="GL-$model-$mac-5G"
	}
    fi
    echo $ssid
}
set_mcu_auto_start(){
    model=$(get_model)
    case "$model" in
        "e750")
            echo [\"auto_start\": \"0\"] > /dev/ttyS0
	    ;;
        *)
    esac
}

mcu_send_message()
{
    local model=$(get_model)
    local name
    if [ "$model" = "e750" ]; then
	#ubus call mcu send_custom_msg "{\"msg\": \"$1\"}"
	if [ "$2" == "wireguard" ]; then
	   if [ -z "$(uci -q get network.wgclient)" ]; then
	      name=`uci -q get wireguard.@peers[0].name`
	   else
	      local config=`uci -q get network.wgclient.config`
	      name=`uci -q get wireguard.$config.name`
	   fi

	   if [ -z "$name" ]; then
	      echo {\"msg\": \"WG NO Configuration File\"} > /dev/ttyS0
	      exit 0
	   else
	      echo {\"msg\": \"$1\"} > /dev/ttyS0
	   fi
	elif [ "$2" == "openvpn" ]; then
	   if [ -z "$(uci -q get network.ovpnclient)" ]; then
	      name=`uci -q get ovpnclient.@clients[0].name`
	   else
	      local config=`uci -q get network.ovpnclient.config`
	      name=`uci -q get ovpnclient.$config.name`
	   fi

	   if [ -z "$name" ]; then
	      echo {\"msg\": \"OVPN NO Configuration File\"} > /dev/ttyS0
	      exit 0
	   else
	      echo {\"msg\": \"$1\"} > /dev/ttyS0
	   fi
        else
	      echo {\"msg\": \"$1\"} > /dev/ttyS0
	fi
    fi
}

set_mini_free_kbytes()
{
    local CTL_FILE="/etc/sysctl.d/12-free-kbytes.conf"
    [ -e "$CTL_FILE"  ] && return
    model=$(get_model)
    case "$model" in
	"ar150" |\
	"ar300m" |\
	"ar750" |\
	"ar750s" |\
	"mifi" |\
	"usb150" |\
	"mt300n-v2" |\
	"xe300" |\
	"x300b" |\
	"x750" |\
        "e750")
            echo "vm.min_free_kbytes=6144" > "$CTL_FILE"
	    ;;
        *)
    esac
}
