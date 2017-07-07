#!/usr/bin/env bash

#ARGS
# - HR min limit
# - HR sequential falls before reboot
if [[ $# -ne 2 ]]; then
    echo "illegal number of parameters"
    exit 1
fi

cd "$(dirname "$0")"

MEMO_FILE=~/.dwarfing.monitor.state

source ./tools.sh
recall $MEMO_FILE

HR_FALL="$HR_FALL"

memo() {
    memorize $MEMO_FILE "HR_FALL"
}

unmemo() {
    HR_FALL=0
    memo
}

#Hash Rate check
HR=`hr_lt $1`
if [[ $HR -eq 1 ]]; then
    HR_FALL=$(($HR_FALL + 1))
    log "HR fall to `read_hr` about $HR_FALL times"
else
    HR_FALL=0
fi

if [[ $HR_FALL -gt $2 ]]; then
    log "REBOOT ->  HR droped to `read_hr` about $HR_FALL times"
    unmemo
    ./reboot.hard.sh reboot 25  
    exit 0
fi

#BAD log check
ERR=`check_miner_for "WATCHDOG: GPU error" "hangs in OpenCL call, exit" "GpuMiner kx failed" "cannot get current temperature, error"`

if [[ $ERR -gt 0 ]]; then
    log "REBOOT find critical errors in miner log"
    unmemo
    ./reboot.hard.sh reboot 25
    exit 0
fi    

#MEMORIZE CURRENT STATE
memo
exit 0


TEST_DATA=$(cat <<EOF
Jul 05 22:57:24 miner3 active[717]: ETH - Total Speed: 92.780 Mh/s, Total Shares: 26, Rejected: 0, Time: 00:20 
Jul 05 22:57:24 miner3 active[717]: ETH: GPU0 28.713 Mh/s, GPU1 17.549 Mh/s, GPU2 17.761 Mh/s, GPU3 28.757 Mh/s 
Jul 05 22:57:32 miner3 active[717]: GPU0 t=72C fan=51%, GPU1 t=70C fan=62%, GPU2 t=66C fan=56%, GPU3 t=72C fan=51%
Jul 05 15:30:15 miner3 active[3519]: GPU 3, GpuMiner kx failed 1 
Jul 05 15:30:15 miner3 active[3519]: GPU 3 failed 
Jul 05 15:30:15 miner3 active[3519]: GPU 3, GpuMiner cu_k1 failed 6, the launch timed out and was terminated 
Jul 07 14:02:52 miner3 active[728]: NVML: cannot get current temperature, error 15 
Jul 07 14:02:55 miner3 active[728]: NVML: cannot get current temperature, error 15
Jul 05 15:30:15 miner3 active[3519]: GPU 3, GpuMiner kx failed 1 
Jul 05 19:36:31 miner1 active[822]: GPU0 t=48C fan=61%; GPU1 t=66C fan=58% 
Jul 05 19:36:31 miner1 active[822]: WATCHDOG: GPU 0 hangs in OpenCL call, exit 
Jul 05 19:36:31 miner1 active[822]: WATCHDOG: GPU 0 hangs in OpenCL call, exit
Jul 05 22:57:24 miner3 active[717]: ETH - Total Speed: 2.780 Mh/s, Total Shares: 26, Rejected: 0, Time: 00:20  
EOF
)
