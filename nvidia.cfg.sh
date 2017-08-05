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


# In your cfg.sh next functions will be available to you
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

# ARGS: gpu_id power_mizer_mode
gpu_pmm() {
    nvidia-settings -a "[gpu:$1]/GpuPowerMizerMode=$2";
}

# ARGS: gpu_id memory_offset_level2 memory_offset_level3
gpu_mtro() {
    # Can only assign to 2 and 3 level
    nvidia-settings -a "[gpu:$1]/GPUMemoryTransferRateOffset[2]=$2" -a "[gpu:$1]/GPUMemoryTransferRateOffset[3]=$3";
}

# ARGS: gpu_id clock_offset_level2 clock_offset_level3
gpu_gco() {
    nvidia-settings -a "[gpu:$1]/GPUGraphicsClockOffset[2]=$2" -a "[gpu:$1]/GPUGraphicsClockOffset[3]=$3"
}

# ARGS: gpu_id fan_control_state
gpu_fcs() {
    nvidia-settings -a "[gpu:$1]/GPUFanControlState=$2"
}

# Get GPU temperature
gpu_temp() {
    nvidia-smi -i $1 --query-gpu=temperature.gpu --format=csv,noheader
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
while true; do
    if [[ ! -f "$1" ]]; then
	echo "Configuration file not found $1"
	sleep 60
	continue
    fi
    
    MDT=`md5sum $1 | awk '{ print $1 }'`
    if [[ "$MD5" != "$MDT" ]]; then
	MD5="$MDT"	
	echo "RE/LOAD configuration from $1"
	source "$1"
    fi
    
    if [[ $RMIN -gt 0 ]]; then
	M=`date +%M | sed -r 's/^0//g'`
	if [[ $((M % RMIN)) -eq 0 ]]; then
	    echo "AUTO RELOAD configuration from $1"
	    source "$1"
	fi
    fi
    sleep 15
done;
