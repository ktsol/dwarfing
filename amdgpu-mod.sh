#!/bin/bash
#
# Ideas stolen from here :)
# https://www.phoronix.com/forums/forum/linux-graphics-x-org-drivers/amd-linux/918649-underclocking-undervolting-the-rx-470-with-amdgpu-pro-success
# Dirver file that should be patched can be found here
# https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/powerplay/smumgr/polaris10_smc.c
#
# This tool modify amd gpu kernel module.
# It allows you to undervolt and underclock your AMD RX4xx GPUs under linux with amdgpu latest driver.
# Use at your own risk.


#COLORS
CRED='\033[0;31m'
CYELL='\033[1;33m'
CGREE='\033[0;32m'
CBLUE='\033[0;34m'
NC='\033[0m' # No Color


function logo {
echo -e "${CBLUE}
____________________________________________________
|              _    __   _                 _    _  |
|  /\   |\/|  | \  /__  |_)  | |    |\/|  / \  | \ |
| /--\  |  |  |_/  \_|  |    |_|    |  |  \_/  |_/ |
|__________________________________________________|${NC}
"
}

function info {
    echo -e "${CGREE}${1}${NC}"
}

function warn {
    echo -e "${CYELL}${1}${NC}"
}


function error {
    echo -e "${CRED}${1}${NC}"
}


function produce_patch {
TPL=$(cat <<EOF
--- ./polaris10_smc.c.orig	2017-04-27 12:00:59.492580016 +0300
+++ polaris10_smc.c		2017-04-27 15:27:55.451783666 +0300
@@ -112,10 +112,15 @@
 			else if (dep_table->entries[i].mvdd)
 				*mvdd = (uint32_t) dep_table->entries[i].mvdd *
 					VOLTAGE_SCALE;
 
 			*voltage |= 1 << PHASES_SHIFT;
+			//MOD UNDERVOLT
+			//UVT_V*voltage = (*voltage & 0xFFFF0000) + (({uvolt}*VOLTAGE_SCALE) & 0xFFFF);
+			//WARNING {uvolt} here must be in (uvolt > 0 && uvolt <= 100)
+			//UVT_P*voltage -= (((*voltage & 0xFFFF) * {uvolt}) / 100) & 0xFFFF;
+			//END UNDRVOLT
 			return 0;
 		}
 	}
 
 	/* sclk is bigger than max sclk in the dependence table */
@@ -134,10 +139,15 @@
 	if (SMU7_VOLTAGE_CONTROL_NONE == data->mvdd_control)
 		*mvdd = data->vbios_boot_state.mvdd_bootup_value * VOLTAGE_SCALE;
 	else if (dep_table->entries[i].mvdd)
 		*mvdd = (uint32_t) dep_table->entries[i - 1].mvdd * VOLTAGE_SCALE;
 
+	//MOD UNDERVOLT
+	//UVT_V*voltage = (*voltage & 0xFFFF0000) + (({uvolt}*VOLTAGE_SCALE) & 0xFFFF);
+	//WARNING {uvolt} here must be in (uvolt > 0 && uvolt <= 100)
+	//UVT_P*voltage -= (((*voltage & 0xFFFF) * {uvolt}) / 100) & 0xFFFF;
+	//END UNDRVOLT
 	return 0;
 }
 
 static uint16_t scale_fan_gain_settings(uint16_t raw_setting)
 {
@@ -770,10 +780,14 @@
 
 	polaris10_get_sclk_range_table(hwmgr, &(smu_data->smc_state_table));
 
 	for (i = 0; i < dpm_table->sclk_table.count; i++) {
 
+		//MOD UNDERCLOCK
+		int clk = dpm_table->sclk_table.dpm_levels[i].value;
+		dpm_table->sclk_table.dpm_levels[i].value -= (clk * {uclock}) / 100;
+		//END UNDERCLOCK
 		result = polaris10_populate_single_graphic_level(hwmgr,
 				dpm_table->sclk_table.dpm_levels[i].value,
 				(uint16_t)smu_data->activity_target[i],
 				&(smu_data->smc_state_table.GraphicsLevel[i]));
 		if (result)
EOF
)
    PATCH=${TPL//"{uvolt}"/$1}
    if [[ $1 -gt 150 ]]; then
	PATCH=${PATCH//"//UVT_V"/""}
    else
	PATCH=${PATCH//"//UVT_P"/""}
    fi
    echo "${PATCH//"{uclock}"/$2}"
}


function show_help {


    echo -e "\nUSAGE:"
    echo -e "Patch:   $0 -d /usr/src/amdgpu-pro-YOURVERSION -v 818 -c 13 # voltage at 818mV underclock 13%"
    echo -e "Patch:   $0 -d /usr/src/amdgpu-pro-YOURVERSION -v 10 -c 5 # downvolt 10% underclock 5%"
    echo -e "Restore: $0 -d /usr/src/amdgpu-pro-YOURVERSION -r"
    echo -e "\nARGUMENTS:"
    echo "    -d DIRECTORY           : Path to directory with your amdgpu driver files"
    echo "    -v VOLTAGE or PERCENT  : Base voltage in mV as int or downvolt in percents if value from 0 to 100"
    echo "    -c PERCENT             : Underclock value in percents"
}


# START PROGRAM
HELP=1
LOGO=1
RESTORE=0
AMDGPUDIR=""
UVOLT=0 #818 in example
UCLOCK=0 #0.87 in example

while getopts "h?rd:v:c:" opt; do
    case "$opt" in
	h|\?) logo; show_help; exit 0 ;;
	d) AMDGPUDIR=$OPTARG; HELP=0 ;;
	r) RESTORE=1; HELP=0 ;;
	v) UVOLT=$((${OPTARG//[!0-9]/})) ;;
	c) UCLOCK=$((${OPTARG//[!0-9]/})) ;;
    esac
done


SNAME=$(basename "$0")
APPDIR="$(dirname "$0")/.${SNAME%.*}"


if [ $LOGO -eq 1 ]; then logo; fi


# VALIDATE INPUT
if [ ! -d "$AMDGPUDIR" ]; then
    error "Provided AMD GPU dir does not exist: ${AMDGPUDIR}"
    show_help; exit 1;
else
    THEFILE="${AMDGPUDIR}/amd/powerplay/smumgr/polaris10_smc.c"
    if [ ! -f "$THEFILE" ]; then
	error "Can not find file to patch: $THEFILE"
	HELP=1
    fi
    BACKUPFILE="${APPDIR}/polaris10_smc.c.orig"
fi

if [[ $RESTORE -eq 0 ]]; then

    USUF="mV"
    if [[ $UVOLT -gt 100 ]]; then
	if [[ $UVOLT -gt 1200 ]]; then warn "Undervolt value ${UVOLT}mV does not look like undervolt at all!"; fi
	if [[ $UVOLT -lt 800  ]]; then warn "Are you shure that it whould work with voltage near ${UVOLT}mV ?"; fi
	if [[ $UVOLT -lt 500  ]];   then  error "Definitely wrong undervolt value ${UVOLT}mV"; HELP=1; fi
    else
	USUF="%"
	if [[ $UVOLT -lt 0 || $UVOLT -gt 50 ]];   then  error "Can not allow you set undervolt to ${UVOLT}%"; HELP=1; fi
    fi
	
    if [[ $UCLOCK -lt 0 || $UCLOCK -gt 50 ]]; then error "Can not allow you set underclock to ${UCLOCK}% !"; HELP=1; fi
    
    info "Undervolt value ${UVOLT}${USUF} underclock is ${UCLOCK}%"
else
    info "Restore configuration requested"
fi

#SHOW HELP on FUCKUP
if [ $HELP -eq 1 ]; then
    show_help
    exit 0
fi


# BEGIN TO WORK
if [[ $EUID -ne 0 ]]; then
    error "No way dude, you have to be a root to do this!"
    exit 1;
fi

if [ ! -d "$APPDIR" ]; then mkdir -p "$APPDIR"; fi

pcheck=`grep -c "//MOD" ${THEFILE}`
if [[ $pcheck -gt 0 ]]; then
    if [ ! -f "$BACKUPFILE" ]; then
        error "Source file are already modified $THEFILE\nBackup file not found at $BACKUPFILE"
	exit 1;
    fi
else
    info "Backup oririnal file to $BACKUPFILE"
    cp -f $THEFILE $BACKUPFILE
fi

# STARTING
info "We are ready to start"
read -p "Continue (y/n)?" choice
echo
if [[ ! $choice =~ ^[Yy]$ ]]
then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi


#PATCH MODE
KERNEL=`uname -r`

KOFILE_PTCH="${APPDIR}/amdgpu.ko_${KERNEL}_${UVOLT}_${UCLOCK}"
if [[ $RESTORE -eq 1 ]]; then
    KOFILE_PTCH="${APPDIR}/amdgpu.ko_${KERNEL}_orig"
fi


if [ ! -f $KOFILE_PTCH ]; then
    info "BUILDING new amdgpu.ko file"

    cp -f "$BACKUPFILE" "$THEFILE"

    if [[ $RESTORE -eq 0 ]]; then
        PTCH=`produce_patch $UVOLT $UCLOCK`
        echo "$PTCH" | patch "$THEFILE"

        if [[ $? -ne 0 ]]; then error "Patching failed with error code: $?"; exit 1; fi
        info "File patched: $THEFILE"
    else
	info "Source restored $THEFILE"
    fi

    cd ${AMDGPUDIR}    
    ${AMDGPUDIR}/pre-build.sh "$KERNEL"
    make KERNELRELEASE="$KERNEL" -C "/lib/modules/$KERNEL/build" M="$AMDGPUDIR"
    if [[ $? -ne 0 ]]; then error "Can not build! Error code: $?"; exit 1; fi
    cp -f "${AMDGPUDIR}/amd/amdgpu/amdgpu.ko" "$KOFILE_PTCH"
else
    info "amdgpu.ko file already precompiled reusing it $KOFILE_PTCH"
fi

find "/lib/modules/$KERNEL" -name amdgpu.ko -exec rm -v {} \;

cp -f "$KOFILE_PTCH" "/lib/modules/${KERNEL}/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko"

depmod -a
update-initramfs -u

info "Looks like everything is ok. Please reboot now"
