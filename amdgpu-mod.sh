#!/bin/bash
#
# Ideas stolen from here :)
# https://www.phoronix.com/forums/forum/linux-graphics-x-org-drivers/amd-linux/918649-underclocking-undervolting-the-rx-470-with-amdgpu-pro-success
#
# This tool modify amd gpu kernel module.
# It allows you to undervolt and underclock your AMD RX4xx GPUs under linux with amdgpu latest driver.
# Use at your own risc.


#COLORS
#Black        0;30     Dark Gray     1;30
#Red          0;31     Light Red     1;31
#Green        0;32     Light Green   1;32
#Brown/Orange 0;33     Yellow        1;33
#Blue         0;34     Light Blue    1;34
#Purple       0;35     Light Purple  1;35
#Cyan         0;36     Light Cyan    1;36
#Light Gray   0;37     White         1;37
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
    echo -e "${CBLUE}${1}${NC}"
}


function produce_patch {
TPL=$(cat <<EOF
--- polaris10_smc.c.orid	2017-04-06 14:53:13.768922151 +0300
+++ polaris10_smc.c	        2017-04-06 17:06:31.804359441 +0300
@@ -112,10 +112,13 @@
 			else if (dep_table->entries[i].mvdd)
 				*mvdd = (uint32_t) dep_table->entries[i].mvdd *
 					VOLTAGE_SCALE;
 
 			*voltage |= 1 << PHASES_SHIFT;
+			//MOD UNDERVOLT
+			*voltage = (*voltage & 0xFFFF0000) + {uvolt}*VOLTAGE_SCALE;
+			//END UNDRVOLT
 			return 0;
 		}
 	}
 
 	/* sclk is bigger than max sclk in the dependence table */
@@ -770,10 +773,14 @@
 
 	polaris10_get_sclk_range_table(hwmgr, &(smu_data->smc_state_table));
 
 	for (i = 0; i < dpm_table->sclk_table.count; i++) {
 
+	        //MOD UNDERCLOCK
+                int clk = dpm_table->sclk_table.dpm_levels[i].value;
+                dpm_table->sclk_table.dpm_levels[i].value -= ({uclock} * clk) / 100;
+		//END UNDERCLOCK
 		result = polaris10_populate_single_graphic_level(hwmgr,
 				dpm_table->sclk_table.dpm_levels[i].value,
 				(uint16_t)smu_data->activity_target[i],
 				&(smu_data->smc_state_table.GraphicsLevel[i]));
 		if (result)
EOF
)
    PATCH=${TPL/"{uvolt}"/$1}
    echo "${PATCH/"{uclock}"/$2}"
}


function show_help {


    echo -e "\nUSAGE:"
    echo -e "Patch:   $0 -d /usr/src/amdgpu-pro-YOURVERSION -v 818 -c 13"
    echo -e "Restore: $0 -d /usr/src/amdgpu-pro-YOURVERSION -r"
    echo "    -v VOLTAGE  : Base voltage in mV as int"
    echo "    -c PERCENTS : Underclock value in percents as int"
}


# START PROGRAM
HELP=1
LOGO=1
RESTORE=0
AMDGPUDIR=""
UVOLT=0 #818 in example
UCLOCK=0 #13 in example

while getopts "h?rd:v:c:" opt; do
    case "$opt" in
	h|\?) logo; show_help; exit 0 ;;
	d) AMDGPUDIR=$OPTARG; HELP=0 ;;
	r) RESTORE=1; HELP=0 ;;
	v) UVOLT=$(($OPTARG)) ;;
	c) UCLOCK=$((OPTARG)) ;;
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
    if [[ $UVOLT -gt 1200 ]]; then warn "Undervolt value ${UVOLT}mV does not look like undervolt at all!"; fi
    if [[ $UVOLT -lt 500  ]]; then warn "Are you shure that it whould work with voltage near ${UVOLT}mV ?"; fi
    if [[ $UVOLT -lt 1  ]];   then  error "Definitely wrong undervold value ${UVOLT}mV"; HELP=1; fi

    if [[ $UCLOCK -gt 90 || $UCLOCK -lt 0 ]]; then error "Can not allow you set underclock at ${UCLOCK}% !"; HELP=1; fi
    info "Undervolt set to ${UVOLT}mV clock reduce value is ${UCLOCK}%"
else
    info "Restore configuration requested"
fi

#SHOW HELP OF FUCKUP
if [ $HELP -eq 1 ]; then
    show_help
    exit 0
fi


# BEGIN TO WORK
if [[ $EUID -ne 0 ]]; then # Пользователь не root
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
    
    ${AMDGPUDIR}/pre-build.sh "$KERNEL"
    make KERNELRELEASE="$KERNEL" -C "/lib/modules/$KERNEL/build" M="$AMDGPUDIR"
    cp -f "${AMDGPUDIR}/amd/amdgpu/amdgpu.ko" "$KOFILE_PTCH"
else
    info "amdgpu.ko file already precompiled reusing it $KOFILE_PTCH"
fi

find /lib/modules/4.4.0-53-generic -name amdgpu.ko -exec rm -v {} \;
find "/lib/modules/$KERNEL" -name amdgpu.ko -exec rm -v {} \;

cp -f "$KOFILE_PTCH" "/lib/modules/${KERNEL}/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko"

depmod -a
update-initramfs -u

info "Looks like everything is ok. Please reboot now"
