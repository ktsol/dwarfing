#!/usr/bin/env bash
# Adding this script to cron let you fix somehow network connection
# if ping failed calling dhclient for provided interface.
# Additionaly you can provide your own command to fix connection.
# It also can reboot computer after n failed attemps to connect
#
# Example
# * * * * * /path.to/reboot.net.monitor.sh eth0 "8.8.8.8" 2 "/etc/init.d/networking restart"
# If ping would fail - will try to dhclient eth0 after networking restart.
# On 3rd fail - reboot.


#ARGS
# - network interface
# - IP addres to ping
# - (optional) number of fails before reboot (0 - no reboot)
# - (optional) Network reconfigure command - will run before dhclient
if [[ $# -le 2 ]]; then
    echo "Required at least 2 arguments"
    exit 1
fi

cd "$(dirname "$0")"

MEMO_FILE=~/.dwarfing.net.monitor.state

source ./tools.sh
recall $MEMO_FILE

memo() {
    memorize $MEMO_FILE "NET_FALL"
}

unmemo() {
    NET_FALL=0
    memo
}

ping -c 3 $2
if [[ "$?" != "0" ]]; then
    log "PING failed to $2"
    NET_FALL=$((NET_FALL + 1))

    if [[ ! -z "$4" ]]; then
	eval $4
    fi
    dhclient $1
fi


if [[ "$3" =~ ^[0-9]+$ ]]; then
    if [[ $NET_FALL -gt $3 ]]; then
	log "REBOOT because of network fails $NET_FALL > $3"
	unmemo
	reboot
	exit 0
    fi
fi    

memo
