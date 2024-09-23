#!/bin/sh
. /lib/functions/gl_util.sh

usb_driver_crash_avoidance_scheme $ACTION

[ "$ACTION" = add -a "$DEVTYPE" = usb_device ] || exit 0
BASENAME="$(basename $DEVPATH)"

[ -f /tmp/usbnode/$BASENAME ] && rm -r /tmp/usbnode/$BASENAME
mkdir -p /tmp/usbnode/$BASENAME
ln -s /sys$DEVPATH /tmp/usbnode/$BASENAME/node
