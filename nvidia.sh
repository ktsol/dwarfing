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


