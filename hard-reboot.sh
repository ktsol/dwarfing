#!/usr/bin/env sh
# Hard system reboot if command execution failed or delayed
# Example: ./hard-reboot.sh "/bin/systemctl restart some_service" 10
#          Will hard reboot if after 10 seconds if service will not be restarted
#          or exited with non zero code

TRIG="/tmp/hard-reboot-ready"

hreboot() {
    sleep $1
    if [ -f "$TRIG" ]; then
	rm -f TRIG
	echo "Hard reboot active"

	echo 1 > /proc/sys/kernel/sysrq 
        echo b > /proc/sysrq-trigger
    else
	echo "NO reboot"
    fi
}


eval_or() {
    touch $TRIG

    eval "$1"
    S=$?
    if [ $S -eq 0 ]; then
	rm -f $TRIG
    fi
    exit $S
}    

hreboot $2 & eval_or "$1"
