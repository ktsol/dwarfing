#!/usr/bin/env bash
# NVIDIA configuration service for server installations without GUI desktop
#
# nvidia-cfg.service Systemd example
#[Unit]
#Description=NVIDIA config service
##BindsTo=X.service # Optional service that provide :99 display
#[Service]
#Environment=DISPLAY=:99
#Type=simple
#ExecStart=/path-to/dwarfing/nvidia.cfg.sh /path/to/cfg.sh [reload_each_n_minute]
#User=root
#Group=root
#Restart=always
#[Install]
#WantedBy=multi-user.target


source "$(dirname "$0")/nvidia.sh"
# In your cfg.sh functions from nvidia.sh  will be available to you
# Also configuration file will be reloaded each time you modify config file
# Configuration will be reloaded every [reload_each_n_minute] minute in hour (value from 1 to 59)
# consider it as some kind of cron job.
# Auto reload feature allow you to configure your fan speed with respect to day time
#
# H=`date +%H`
# if [[ $H -ge 8 && $H -lt 20 ]]; then
#     echo "FAN day"
# else
#     echo "FAN night-evening"
# fi
#
# echo "Run file counter $CFG_RUN"
# if [[ $CFG_RUN -eq 0 ]]; then
#     echo "This code will run once at start or after config was changed";
# fi


# ACTUAL SERVICE CODE
# We want to sustain X session, that is why we need infinite loop here
# Also it can reload config if it changed
echo "INTIALIZE NVIDIA CONFIG SERVICE"
echo "Configuration file path $1"


RMIN="$2"
if [[ $RMIN =~ ^[0-9]+$ ]]; then
    RMIN=$((RMIN % 60))
    echo "AUTO RELOAD ENABLED for each $RMIN minute in hour"
else
    RSEC=0
    echo "AUTO RELOAD DISABLED"
fi


MD5=""
CFG_RUN=0
while true; do
    if [[ ! -f "$1" ]]; then
	echo "Configuration file not found $1"
	sleep 60
	continue
    fi
    
    MDT=`md5sum $1 | awk '{ print $1 }'`
    if [[ "$MD5" != "$MDT" ]]; then
	MD5="$MDT"
	CFG_RUN=0
	echo "RE/LOAD config. File was modified $1"
	source "$1"
    fi
    
    if [[ $RMIN -gt 0 ]]; then
	M=`date +%M | sed -r 's/^0//g'`
	if [[ $((M % RMIN)) -eq 0 ]]; then
	    CFG_RUN=$((CFG_RUN + 1))
	    echo "AUTO RELOAD configuration from $1"
	    source "$1"
	fi
    fi
    sleep 15
done;
