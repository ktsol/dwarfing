#!/usr/bin/env bash
# Hard system reboot if command execution failed or delayed
# Example: ./hard-reboot.sh "/bin/systemctl restart some_service" 10
#          Will hard reboot if after 10 seconds if service will not be restarted
#          or exited with non zero code
if [[ $# -ne 2 ]]; then
    echo "Illegal number $# of parameters"
    exit 1
fi

TRIG="/tmp/hard-reboot-ready"

reboot_hard() {
    sleep $1
    if [[ -f "$TRIG" ]]; then
	rm -f TRIG
	echo "(O_O) Hard reboot activated"
	echo 1 > /proc/sys/kernel/sysrq
        echo b > /proc/sysrq-trigger
    else
	echo "(^_^) No need for hard reboot"
    fi
}

eval_or() {
    touch $TRIG
    eval $1
    S=$?
    if [ $S -eq 0 ]; then
	rm -f $TRIG
    fi
    exit $S
}    

reboot_hard_on_command_fail() {
    reboot_hard $2 & eval_or $1
}

reboot_hard_on_command_fail $1 $2
