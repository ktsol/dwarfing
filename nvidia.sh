#!/usr/bin/env sh
# This is set of handy shell functions to control NVidia GPUs
# You can use in your shell by calling $source ...nvidia.sh


# Get GPU temperature
# ARGS: gpu_id
gpu_temp() {
    nvidia-smi -i $1 --query-gpu=temperature.gpu --format=csv,noheader,nounits
}


# Set GPU Power limit
# ARGS: gpu_id power_limit
gpu_pl() {
    PL=$(nvidia-smi -i $1 --format=csv,noheader,nounits --query-gpu='power.limit' | grep -oP '\K\d+(?=\.\d+.*)')
    if [ "$PL" != "$2" ]; then
	nvidia-smi -i $1 -pl $2
    else
	echo "SKIP power limit update with same value $2"
    fi
}


# Decrease power_limit at some pl_step * (degrees more than temp_trigger) if GPU temperature > temp_trigger
# ARGS: gpu_id power_limit temp_trigger pl_step
gpu_pl_by_temperature() {
    T=$(gpu_temp $1)
    if [ $T -gt $3 ]; then
	d=$(($T - $3))
	pl=$(($2 - $d * $4))
	plm=$(nvidia-smi --format=csv,noheader,nounits --query-gpu=power.min_limit -i $1 | grep -oP '\K\d+(?=\.\d+.*)')
	
	if [ $pl -lt $plm ]; then
	    echo "GPU$1 ${T}C -> power limit to to $plm"
	    gpu_pl $1 $plm
	else
	    echo "GPU$1 ${T}C -> power limit to to $pl"
	    gpu_pl $1 $pl
	fi
    fi
    
    if [ $T -lt $3 ]; then
	gpu_pl $1 $2
    fi
}


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


#
# FAN CONTROL
#

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
