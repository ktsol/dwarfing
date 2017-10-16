#!/usr/bin/env bash

log() {
    TS=$(date +%Y-%m-%d)' '$(date +%H:%M:%S)
    echo "$TS $@" | cat >> ~/.dwarfing.log
}

memorize() {
    echo "#MEMORIZED VALUES" | cat > "$1"
    for V in "${@:2}"; do
	echo "${V}=\"${!V}\"" | cat >> "$1";
    done    
}

recall() {
    if [[ ! -f "$1" ]]; then
	echo "#EMPTY RECALL" | cat > "$1"
	for V in "${@:2}"; do
	    echo "${V}=\"\"" | cat >> "$1";
	done

    fi
    source $1
}

read_journal() {
    journalctl -b 0 -n $2 -o cat -eu $1;
}

read_miner() {
    read_journal miner $1;
}

check_miner_for() {
    O=`read_miner 10`
    R=0
    for S in "${@}"; do
	if [[ $O == *"$S"* ]]; then
	    R=1
	fi
    done
    echo $R;
}

# Read hashrate from systemd "miner" service
# Supported miners outputs:
# - claymore (single crypto)
# - ccminer
# - ewbf
read_hr() {
    read_miner 100 | tac - | grep -m 1 -oPi '(Total Speed:\s+|accepted:[^\)]+\), )\K(\d+)(?=(\.\d+)*\s.*)'
}

# Check if system "miner" serice hash rate less that provided
hr_lt() {
    if [ $(systemctl is-active miner) != "active" ]; then
	# Inactive miner
	echo 0;
    fi
    
    hrs=`read_hr`
    if [ -z $hrs ]; then
	echo 1;
    else
	if [ $hrs -lt $1 ]; then
	    echo 1;
	else
	    echo 0;
	fi
    fi
}
