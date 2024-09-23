#!/bin/sh

. /lib/functions/modem.sh

sleep 30

bus=$(get_modem_bus)

operator=$(get_operator_type)
[ "$operator" != "Verizon" ] && exit 0


count=0
while true
do
	sleep 5
	APN=$(gl_modem -B $bus AT AT+CGDCONT? | grep "+CGDCONT: 1")
	[ $APN = "" ] && {
		count=$((count+1))
		[ $count -gt 20 ] && exit 0
		continue
	}

	apn_check=`echo $APN | grep -E 'ims|IMS'`
	if [ "$apn_check" = "" ];then
		gl_modem -B $bus SAT sp AT+QNVFD=\"/data/andsf.xml\"
		gl_modem -B $bus SAT sp AT+QMBNCFG=\"deactivate\"
		gl_modem -B $bus SAT sp AT+QMBNCFG=\"autosel\",1

		sleep 1
		reboot
	else
		exit 0
	fi
done
