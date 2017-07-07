#!/usr/bin/env bash
# NVIDIA configuration service for server installations without GUI desktop
#
# nvidia-cfg.service Systemd example
#[Unit]
#Description=NVIDIA config service
#[Service]
#Type=simple
#ExecStart=/usr/bin/xinit /path-to/dwarfing/nvidia.cfg.sh /path/to/cfg.sh -- :1 -once
#User=miner
#Group=miner
#Restart=always
#[Install]
#WantedBy=multi-user.target


# In your cfg.sh next functions will be available to you
# Also configuration file will be reloaded each time you modify it

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
    nvidia-settings -a "[gpu:$1]/GPUGraphicsClockOffset[2]=$3" -a "[gpu:$1]/GPUGraphicsClockOffset[3]=$3"
}

# ARGS: gpu_id fan_control_state
gpu_fcs() {
    nvidia-settings -a "[gpu:$1]/GPUFanControlState=$2"
}

# ARGS: gpu_id fan_speed_percent
gpu_tfs() {
    nvidia-settings -a "[gpu:$1]/GPUFanControlState=1" -a "[fan:$1]/GPUTargetFanSpeed=$2"
}


# ACTUAL SERVICE CODE
# We want to sustain X session, that is why we need infinite loop here
# Also it can reload config if it changed

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
    sleep 15
done;
