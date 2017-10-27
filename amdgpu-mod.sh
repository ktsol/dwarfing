#!/usr/bin/env bash
#
# Basic idea stolen from here
# https://www.phoronix.com/forums/forum/linux-graphics-x-org-drivers/amd-linux/918649-underclocking-undervolting-the-rx-470-with-amdgpu-pro-success
#
# After this I came to my own downclock idea.
# It working with a little mess in pp_dpm_sclk output,
# but unfortunately it seems that compiling downclock ratio
# gives much better power saving.
#
# Also I've tried to backbort DAG fix, but witout any success
# https://patchwork.freedesktop.org/patch/174700/
#
# This tool modify amd gpu kernel module.
# It allows you to undervolt and underclock your AMD RXxx GPUs under linux with amdgpu latest driver.
#
# BE CAREFULL!
# I DO NOT REALLY UDERSTAND HOW DOES IT WORK AND WFT I'M DOING

# colors
CRED='\033[0;31m'; CYELL='\033[1;33m'; CGREE='\033[0;32m'; CBLUE='\033[0;34m'; NC='\033[0m';

function logo {
echo -e "${CBLUE}
____________________________________________________
|              _    __   _                 _    _  |
|  /\   |\/|  | \  /__  |_)  | |    |\/|  / \  | \ |
| /--\  |  |  |_/  \_|  |    |_|    |  |  \_/  |_/ |
|__________________________________________________|${NC}
"
}

function info { echo -e "${CGREE}${1}${NC}"; }
function warn { echo -e "${CYELL}${1}${NC}"; }
function error { echo -e "${CRED}${1}${NC}"; }

FILE_DAG="/amd/amdgpu/amdgpu_vm.c"
FILE_P10="/amd/powerplay/smumgr/polaris10_smc.c"
FILE_HW_SMU7="/amd/powerplay/hwmgr/smu7_hwmgr.c"
FILE_HW_VEGA="/amd/powerplay/hwmgr/vega10_hwmgr.c"

function backup_src_file {
    if [ ! -f "$1" ]; then error "Source not found $1"; exit 1; fi
    if [ -f "$2" ]; then
	info "SKIP bakup, file aready exist $2";
    else
	mkdir -p "$(dirname "$2")";
	cp -f "$1" "$2";
	if [ $? -ne 0 ]; then error "Can not backup $1 -> $2"; exit 1; fi
    fi
}

function backup_src {
    backup_src_file "${1}$FILE_DAG" "${2}$FILE_DAG"
    backup_src_file "${1}$FILE_P10" "${2}$FILE_P10"
    backup_src_file "${1}$FILE_HW_SMU7" "${2}$FILE_HW_SMU7"
    backup_src_file "${1}$FILE_HW_VEGA" "${2}$FILE_HW_VEGA"
}

# $1-backup file
# $2-amd source loc
# $3-patch
function patch_restore_file {
    cp -f "$1" "$2"
    if [ $RESTORE -eq 0 ]; then
	info "Patch file $2"
        echo "$3" | patch "$2"
        if [ $? -ne 0 ]; then error "Patching failed with error code: $?"; echo "$3";  exit 1; fi
        info "File patched: $2"
    else
	info "Source restored $2"
    fi
}

PATCH_SMU7=$(cat <<EOF
--- .smu7_hwmgr.c.orig	2017-08-04 12:59:00.000000000 +0300
+++ .smu7_hwmgr.c	2017-09-12 22:59:37.650864941 +0300
@@ -4379,23 +4379,50 @@
 	struct smu7_hwmgr *data = (struct smu7_hwmgr *)(hwmgr->backend);
 	struct smu7_single_dpm_table *golden_sclk_table =
 			&(data->golden_dpm_table.sclk_table);
+    struct smu7_single_dpm_table *sclk_table =
+            &(data->dpm_table.sclk_table);
 	struct pp_power_state  *ps;
 	struct smu7_power_state  *smu7_ps;
 
-	if (value > 20)
-		value = 20;
-
 	ps = hwmgr->request_ps;
 
 	if (ps == NULL)
 		return -EINVAL;
 
 	smu7_ps = cast_phw_smu7_power_state(&ps->hardware);
-
-	smu7_ps->performance_levels[smu7_ps->performance_level_count - 1].engine_clock =
-			golden_sclk_table->dpm_levels[golden_sclk_table->count - 1].value *
-			value / 100 +
-			golden_sclk_table->dpm_levels[golden_sclk_table->count - 1].value;
+    
+    bool up = true;
+    if (value >= 50) {
+        if (value > 99) value = 99;
+        value = 100 - value;
+        up = false;
+    } else if (value > 20) 
+        value = 20;
+
+    int i;
+    for (i = 1; i <= smu7_ps->performance_level_count; i++) {
+        uint32_t clock = golden_sclk_table->dpm_levels[golden_sclk_table->count - i].value;
+        if (up)
+            clock += golden_sclk_table->dpm_levels[golden_sclk_table->count - i].value * value / 100;
+        else
+            clock -= golden_sclk_table->dpm_levels[golden_sclk_table->count - i].value * value / 100;
+        smu7_ps->performance_levels[smu7_ps->performance_level_count - i].engine_clock = clock;
+    }
+   
+    // Only downclock or reset to normal (looks like it does not work properly)
+    if (value <= 20)
+        value = 0;
+    
+    uint32_t min_clock = sclk_table->dpm_levels[0].value;
+    for (i = 1; i < sclk_table->count; i++) {
+        uint32_t clock = golden_sclk_table->dpm_levels[i].value;
+        clock -= golden_sclk_table->dpm_levels[i].value * value / 100;
+
+        if (clock < min_clock)
+            sclk_table->dpm_levels[i].value = min_clock;
+        else
+            sclk_table->dpm_levels[i].value = clock;
+    }
 
 	return 0;
 }
EOF
)

PATCH_VEGA=$(cat <<EOF

EOF
)

# This patch does not work but I just leave it here
PATCH_DAG=$(cat <<EOF
--- .amdgpu_vm.c.orig	2017-08-04 12:59:00.000000000 +0300
+++ .amdgpu_vm.c	2017-09-25 13:08:55.950264370 +0300
@@ -1291,35 +1291,65 @@
 	 */
 
 	/* SI and newer are optimized for 64KB */
-	uint64_t frag_flags = AMDGPU_PTE_FRAG(AMDGPU_LOG2_PAGES_PER_FRAG);
-	uint64_t frag_align = 1 << AMDGPU_LOG2_PAGES_PER_FRAG;
 
-	uint64_t frag_start = ALIGN(start, frag_align);
-	uint64_t frag_end = end & ~(frag_align - 1);
+
+    // There is no vm_fragment_size in 17.30 drivers yes
+    // People sad that vm_fragment_size = 9 is DAG fix so i will hardcode it
+    unsigned max_frag = 9;
 
 	/* system pages are non continuously */
-	if (params->src || !(flags & AMDGPU_PTE_VALID) ||
-	    (frag_start >= frag_end)) {
-
+    if (params->src || !(flags & AMDGPU_PTE_VALID)) {
 		amdgpu_vm_update_ptes(params, start, end, dst, flags);
 		return;
 	}
 
 	/* handle the 4K area at the beginning */
-	if (start != frag_start) {
-		amdgpu_vm_update_ptes(params, start, frag_start,
-				      dst, flags);
-		dst += (frag_start - start) * AMDGPU_GPU_PAGE_SIZE;
-	}
-
-	/* handle the area in the middle */
-	amdgpu_vm_update_ptes(params, frag_start, frag_end, dst,
-			      flags | frag_flags);
-
-	/* handle the 4K area at the end */
-	if (frag_end != end) {
-		dst += (frag_end - frag_start) * AMDGPU_GPU_PAGE_SIZE;
-		amdgpu_vm_update_ptes(params, frag_end, end, dst, flags);
+    while (start != end) {
+        uint64_t frag_flags, frag_end;
+        unsigned frag;
+
+        /* This intentionally wraps around if no bit is set */
+        frag = min((unsigned) ffs(start) - 1,
+                (unsigned) fls64(end - start) - 1);
+        if (frag >= max_frag) {
+            frag_flags = AMDGPU_PTE_FRAG(max_frag);
+            frag_end = end & ~((1ULL << max_frag) - 1);
+        } else {
+            frag_flags = AMDGPU_PTE_FRAG(frag);
+            frag_end = start + (1 << frag);
+        }
+
+        amdgpu_vm_update_ptes(params, start, frag_end, dst,
+                +flags | frag_flags);
+        
+        // can not do it for this method signature
+        //if (r)
+        //    return r; 
+        dst += (frag_end - start) * AMDGPU_GPU_PAGE_SIZE;
+        start = frag_end;
 	}
 }
 
@@ -1398,8 +1428,12 @@
 		/* set page commands needed */
 		ndw += ncmds * 10;
 
-		/* two extra commands for begin/end of fragment */
-		ndw += 2 * 10;
+        /* extra commands for begin/end fragments */
+        // There is no vm_fragment_size in 17.30 drivers yes
+        // People sad that vm_fragment_size = 9 is DAG fix so i will hardcode it
+        ndw += 2 * 10 * 9;
 
 		params.func = amdgpu_vm_do_set_ptes;
 	}

EOF
)

function produce_patch {
TPL=$(cat <<EOF
--- ./polaris10_smc.c.orig	2017-04-27 12:00:59.492580016 +0300
+++ polaris10_smc.c		2017-04-27 15:27:55.451783666 +0300
@@ -112,10 +112,13 @@
 			else if (dep_table->entries[i].mvdd)
 				*mvdd = (uint32_t) dep_table->entries[i].mvdd *
 					VOLTAGE_SCALE;
 
 			*voltage |= 1 << PHASES_SHIFT;
+			//MOD UNDERVOLT
+			//UVT_V*voltage = (*voltage & 0xFFFF0000) + (({uvolt}*VOLTAGE_SCALE) & 0xFFFF);
+			//END UNDRVOLT
 			return 0;
 		}
 	}
 
 	/* sclk is bigger than max sclk in the dependence table */
@@ -134,10 +139,13 @@
 	if (SMU7_VOLTAGE_CONTROL_NONE == data->mvdd_control)
 		*mvdd = data->vbios_boot_state.mvdd_bootup_value * VOLTAGE_SCALE;
 	else if (dep_table->entries[i].mvdd)
 		*mvdd = (uint32_t) dep_table->entries[i - 1].mvdd * VOLTAGE_SCALE;
 
+	//MOD UNDERVOLT
+	//UVT_V*voltage = (*voltage & 0xFFFF0000) + (({uvolt}*VOLTAGE_SCALE) & 0xFFFF);
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
    PATCH=${PATCH//"//UVT_V"/""}
    echo "${PATCH//"{uclock}"/$2}"    
}


function show_help {
    echo -e "\nUSAGE:"
    echo -e "Patch:   $0 -d /usr/src/amdgpu-pro-YOURVERSION -v 800 -c 13 # voltage at 818mV underclock 13%"
    echo -e "Restore: $0 -d /usr/src/amdgpu-pro-YOURVERSION -r"
    echo -e "\nARGUMENTS:"
    echo "    -d DIRECTORY           : Path to directory with your amdgpu driver files"
    echo "    -v VOLTAGE             : Base voltage in mV as int"
    echo "    -c PERCENT             : Underclock value in percents"
}


# START PROGRAM
HELP=1
LOGO=1
RESTORE=0
AMDGPUDIR=""
UVOLT=0
UCLOCK=0

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
KERNEL=`uname -r`

if [ $LOGO -eq 1 ]; then logo; fi

# VALIDATE INPUT
if [ ! -d "$AMDGPUDIR" ]; then
    error "Provided AMD GPU dir does not exist: ${AMDGPUDIR}"
    show_help; exit 1;
else
    SRCDIR="${APPDIR}/$(basename "$AMDGPUDIR")"
fi

if [ $RESTORE -eq 0 ]; then
    if [ $UVOLT -gt 1200 ]; then warn "Undervolt value ${UVOLT}mV does not look like undervolt at all!"; fi
    if [ $UVOLT -lt 800  ]; then warn "Are you shure that it whould work with voltage near ${UVOLT}mV ?"; fi
    if [ $UVOLT -lt 700  ];   then  error "Definitely wrong undervolt value ${UVOLT}mV"; HELP=1; fi
    if [ $UCLOCK -lt 0 ] || [ $UCLOCK -gt 50 ]; then error "Can not allow you set underclock to ${UCLOCK}% !"; HELP=1; fi
    
    info "Undervolt value ${UVOLT}mV underclock is ${UCLOCK}%"
else
    info "Restore configuration requested"
fi

#SHOW HELP on FUCKUP
if [ $HELP -eq 1 ]; then show_help; exit 0; fi


# BEGIN TO WORK
if [ $EUID -ne 0 ]; then
    error "No way dude, you have to be a root to do this!"
    exit 1;
fi

if [ ! -d "$SRCDIR" ]; then mkdir -p "$SRCDIR"; fi #This also creates APPDIR

# STARTING
backup_src "$AMDGPUDIR" "$SRCDIR"

info "We are ready to start"
read -p "Continue (y/n)?" yn
echo
if [ $yn != "Y" ] && [ $yn != "y" ]; then
    [ "$0" = "$BASH_SOURCE" ] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

#PATCH MODE
KOFILE_PTCH="${APPDIR}/${KERNEL}/amdgpu.ko_${KERNEL}_${UVOLT}_${UCLOCK}"

if [ $RESTORE -eq 1 ]; then
    KOFILE_PTCH="${APPDIR}/${KERNEL}/amdgpu.ko_${KERNEL}_orig"
fi

if [ ! -f $KOFILE_PTCH ]; then
    info "BUILDING new amdgpu.ko file"
    mkdir -p "$(dirname "$KOFILE_PTCH")"
    
    PATCH_UVC=`produce_patch $UVOLT $UCLOCK`
    patch_restore_file "${SRCDIR}${FILE_P10}" "${AMDGPUDIR}${FILE_P10}" "$PATCH_UVC"
    patch_restore_file "${SRCDIR}${FILE_HW_SMU7}" "${AMDGPUDIR}${FILE_HW_SMU7}" "$PATCH_SMU7"
    #patch_restore_file "${SRCDIR}${FILE_DAG}" "${AMDGPUDIR}${FILE_DAG}" "$PATCH_DAG"

    cd ${AMDGPUDIR}    
    ${AMDGPUDIR}/pre-build.sh "$KERNEL"
    make KERNELRELEASE="$KERNEL" -C "/lib/modules/$KERNEL/build" M="$AMDGPUDIR"
    res=$?
    cd -
    if [ $res -ne 0 ]; then error "Can not build! Error code: $?"; exit 1; fi
    cp -f "${AMDGPUDIR}/amd/amdgpu/amdgpu.ko" "$KOFILE_PTCH"
else
    info "amdgpu.ko file already precompiled reusing it $KOFILE_PTCH"
fi

find "/lib/modules/$KERNEL" -name amdgpu.ko -exec rm -v {} \;

cp -f "$KOFILE_PTCH" "/lib/modules/${KERNEL}/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko"

depmod -a
update-initramfs -u

info "SUCCESS"
echo "Looks like everything is ok. Please reboot now."
info "DOWNCLOCK USAGE MANUAL"
echo "By default you can write into hwmon file device/pp_sclk_od value from 0 to 20."
echo "This will increase your clock up to 20%."
echo "With my patch you can also decrease clock down from 99% to 50%."
echo "Just write value from 50 to 99 to device/pp_sclk_od"
echo "It may cause mess while reading pp_sclk_od and pp_dmp_sclk values."
