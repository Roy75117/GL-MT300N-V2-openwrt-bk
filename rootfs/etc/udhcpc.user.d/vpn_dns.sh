#!/bin/sh
[ -f /tmp/resolv.conf.d/resolv.conf.wg ] && cp /tmp/resolv.conf.d/resolv.conf.wg /tmp/resolv.conf.wg && mv /tmp/resolv.conf.wg /tmp/resolv.conf.d
[ -f /tmp/resolv.conf.d/resolv.conf.ovpn ] && cp /tmp/resolv.conf.d/resolv.conf.ovpn /tmp/resolv.conf.ovpn && mv /tmp/resolv.conf.ovpn /tmp/resolv.conf.d
