#!/bin/sh -e
#back up installed pkb without pkg version
opkg list-installed > list-tmp
cut -d ' ' -f 1 list-tmp > list-installed.txt
rm list-tmp