#!/usr/bin/env bash
# NVIDIA configuration service for server installations without GUI desktop
#
# nvidia-cfg.service Systemd example
#[Unit]
#Description=NVIDIA config service
#[Service]
#Type=simple
#ExecStart=/usr/bin/xinit /path-to/dwarfing/nvidia.cfg.sh /path/to/cfg.sh [reload_each_n_minute] -- :1 -once
#User=miner
#Group=miner
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


# ARGS: gpu_id power_mizer_mode
gpu_pmm() {
    nvidia-settings -a "[gpu:$1]/GpuPowerMizerMode=$2";
}


# ARGS: gpu_id memory_offset_level3 [memory_offset_level2]
gpu_mtro() {
    Q="[gpu:$1]/GPUMemoryTransferRateOffset"
    O3=`nvidia-settings -q $Q | grep -oP ']\):\s+\K-{0,1}\d+(?=\.)'`

    if [[ "$O3" != "$2" ]]; then
	# Can only assign to 2 and 3 level
	nvidia-settings -a "[gpu:$1]/GPUMemoryTransferRateOffset[3]=$2";
	if [[ ! -z "$3" ]]; then
	    nvidia-settings -a "[gpu:$1]/GPUMemoryTransferRateOffset[2]=$3";
	fi
    else
	echo "SKIP update GPUMemoryTransferRateOffset[3] with same value $2"
    fi
}


# ARGS: gpu_id clock_offset_level3 [clock_offset_level2]
gpu_gco() {
    Q="[gpu:$1]/GPUGraphicsClockOffset"
    O3=`nvidia-settings -q $Q | grep -oP ']\):\s+\K-{0,1}\d+(?=\.)'`

    if [[ "$O3" != "$2" ]]; then
	# Can only assign to 2 and 3 level
	nvidia-settings  -a "[gpu:$1]/GPUGraphicsClockOffset[3]=$2"
	if [[ ! -z "$3" ]]; then
	    nvidia-settings -a "[gpu:$1]/GPUGraphicsClockOffset[2]=$3"
	fi	
    else
	echo "SKIP update GPUGraphicsClockOffset[3] with same value $2"
    fi
}


# ARGS: gpu_id fan_control_state
gpu_fcs() {
    nvidia-settings -a "[gpu:$1]/GPUFanControlState=$2"
}


# ARGS: gpu_id fan_speed_percent [critical_temperature]
# WIll set fan at 100 if temperature is critical
gpu_tfs() {
    tl="$3"
    fan="$2"
    if [[ $tl =~ ^[0-9]+$ ]]; then
	t=`gpu_temp $1`
	if [[ $t -ge $tl ]]; then
	    echo "GPU $1 FAN at 100% -> Temperature $t >= $tl"
	    fan=100
	fi
    fi
    
    nvidia-settings -a "[gpu:$1]/GPUFanControlState=1" -a "[fan:$1]/GPUTargetFanSpeed=$fan"
}


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
