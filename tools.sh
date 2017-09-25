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
    journalctl -n $2 -o cat -eu $1;
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

read_hr() {
    read_miner 20 | grep -m 1 -oP 'Total Speed:\s+\K(\d+)(?=\.\d+\s.*)'
}

#Hash rate less that provided
hr_lt() {
    hrs=`read_hr`
    if [[ -z $hrs ]]; then
	echo 0;
    else
	if [[ $hrs -lt $1 ]]; then
	    echo 1;
	else
	    echo 0;
	fi
    fi
}
