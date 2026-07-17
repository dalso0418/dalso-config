#!/bin/bash

# Color Palette
G='\033[1;32m'
R='\033[0;31m'
B='\033[0;34m'
Y='\033[0;33m'
N='\033[0m'

BACKTITLE="Xpenology VM Installer for Proxmox VE"
STEP_TOTAL=6
# CURRENT_STEP is set by the main loop (1-based) so wrappers can render "Step N/6".
CURRENT_STEP=1

# --- i18n ---
LANG_CHOICE="en"   # "en" | "ko"; overridden by pick_language

declare -A MSG_en=(
    [quit_title]="Exit installer?"
    [quit_body]="Quit the Xpenology installer? Your choices will be lost."
    [backtitle]="Xpenology VM Installer for Proxmox VE"
    [root_err]="This script must be run as root."
    [canceled]="Canceled."
    [err_title]="Invalid"
    [err_generic]="Error"
    [creating_vm]="Creating VM %s..."
    [sec_core]="Core VM"
    [core_vmid_prompt]="Enter VM ID"
    [core_vmname_prompt]="Enter VM Name"
    [core_cores_prompt]="Enter CPU Cores"
    [core_ram_prompt]="Enter RAM in MB"
    [err_vmid_empty]="VM ID cannot be empty."
    [err_vmid]="VM ID must be an integer."
    [err_vmname_empty]="VM Name cannot be empty."
    [err_cores]="Invalid number of cores."
    [err_ram]="Invalid RAM size."
    [sec_disk]="Data Disk"
    [disk_bus_prompt]="Select the disk bus type for the VM."
    [sec_storage_mode]="Storage Mode"
    [storage_mode_prompt]="Choose how the VM gets its data disk(s)."
    [mode_virtual]="Create a virtual data disk"
    [mode_passthrough]="Pass through physical disk(s)"
    [disk_size_prompt]="Enter Data Disk Size in GB"
    [err_disk_size]="Invalid disk size."
    [storage_select_prompt]="Select storage for the DATA disk (%sG)."
    [sec_passthrough]="Disk Passthrough"
    [pt_no_free_title]="No free disks"
    [pt_no_free_body]="No unused physical disks were found. (All disks appear mounted, part of LVM/ZFS/RAID, the boot disk, or already attached to a VM.)"
    [pt_heads_up_title]="Heads up"
    [pt_heads_up_body]="%s disk(s) are hidden because they appear in use (boot/LVM/ZFS/RAID/mounted or claimed by a VM). Only safe, unused disks are listed."
    [pt_select_prompt]="Select physical disk(s) to pass through (space toggles):"
    [pt_nothing_title]="Nothing selected"
    [pt_nothing_body]="Select at least one disk, or go Back to choose a virtual disk."
    [pt_confirm_title]="Confirm passthrough"
    [pt_confirm_body]="These PHYSICAL disks will be attached to VM %s as-is. Make sure they are NOT used by the host or another VM — doing so can cause data loss.%s\n\nProceed?"
    [sec_storage]="Storage"
    [sec_network]="Network"
    [storage_none_body]="No suitable storage with available space found for content type '%s'."
    [bridge_none_body]="No active network bridge found."
    [network_select_prompt]="Select the network bridge for the VM."
    [sec_bootloader]="Bootloader"
    [boot_prompt]="Choose a bootloader image"
    [boot_resolving]="Resolving latest %s version..."
    [boot_net_err_title]="Network"
    [boot_net_err_body]="Could not reach GitHub to resolve the latest version. Check connectivity and retry."
    [boot_empty_tag]="Empty version tag resolved."
    [boot_url_err]="Could not build download URL."
    [createSerial]="Would you like to add a virtual serial port?"
    [createSerialDesc]="If an issue occurs, you can easily troubleshoot it by connecting with xterm.js."
    [serial_yes]="Added"
    [serial_no]="Not added"
    [sec_review]="Review & Create"
    [review_prompt]="Review your configuration, then create the VM:"
    [review_create]="==> Create VM now <=="
    [rev_vmid]="VM ID"
    [rev_vmname]="VM Name"
    [rev_cores]="CPU Cores"
    [rev_ram]="RAM"
    [rev_bus]="Disk Bus"
    [rev_storage]="Storage"
    [rev_bridge]="Network Bridge"
    [rev_bootloader]="Bootloader"
    [rev_serial]="Virtual Serial Port"
    [serial_enabled]="Enabled"
    [serial_disabled]="Disabled"
    [storage_line_virtual]="virtual %sG on %s"
    [storage_line_passthrough]="passthrough (%s disk(s))"
    [pt_create_guard_title]="No data disk"
    [pt_create_guard_body]="Passthrough mode is selected but no physical disks are chosen. Edit Storage to pick disk(s), or switch to a virtual disk."
    [dl_label]="Downloading %s %s..."
    [dl_fail_title]="Download failed"
    [dl_fail_body]="Download failed. Retry?"
    [extracting_title]="Extracting"
    [extracting_body]="Extracting %s image..."
    [extract_fail_title]="Extract failed"
    [extract_fail_body]="Could not find the .img after extraction. Retry?"
    [vm_config_done]="VM configuration complete!"
    [start_title]="Start VM?"
    [start_body]="Would you like to start the new virtual machine now?"
    [vm_create_failed]="VM creation failed."
    [disk_attach_failed]="Failed to attach data disk."
    [pt_attach_failed]="Failed to pass through disk: %s"
    [serial_attach_failed]="Failed to add the virtual serial port."
    [rollback_title]="Rollback"
    [rollback_body]="Destroy partially-created VM %s?"
    [status_started]="Started"
    [status_not_started]="Created (Not Started)"
    [summary_header]="--- VM Summary ---"
    [sum_vmid]="VM ID: %s"
    [sum_vmname]="VM Name: %s"
    [sum_status]="Status: %s"
    [sum_cores]="CPU Cores: %s"
    [sum_ram]="RAM: %s MB"
    [sum_bus]="Disk Bus: %s"
    [sum_network]="Network: %s"
    [sum_bootloader]="Bootloader: %s %s (attached from %s)"
    [sum_serial]="Virtual Serial Port: %s"
    [sum_data_passthrough]="Data Disks (passthrough):"
    [sum_disk_item]="  - %s"
    [sum_data_virtual]="Data Disk: %sG on %s"
    [summary_footer]="------------------"
    [sum_manage]="You can now manage the VM from the Proxmox web interface."
    [btn_back]="Back"
    [btn_cancel]="Cancel"
    [step_word]="Step"
)
declare -A MSG_ko=(
    [quit_title]="설치 종료?"
    [quit_body]="Xpenology 설치를 종료할까요? 선택한 내용이 사라집니다."
    [backtitle]="Proxmox VE용 Xpenology VM 설치 마법사"
    [root_err]="이 스크립트는 root로 실행해야 합니다."
    [canceled]="취소되었습니다."
    [err_title]="입력 오류"
    [err_generic]="오류"
    [creating_vm]="VM %s 생성 중..."
    [sec_core]="기본 VM 설정"
    [core_vmid_prompt]="VM ID를 입력하세요"
    [core_vmname_prompt]="VM 이름을 입력하세요"
    [core_cores_prompt]="CPU 코어 수를 입력하세요"
    [core_ram_prompt]="RAM 용량(MB)을 입력하세요"
    [err_vmid_empty]="VM ID는 비워둘 수 없습니다."
    [err_vmid]="VM ID는 정수로 입력해야 합니다."
    [err_vmname_empty]="VM 이름은 비워둘 수 없습니다."
    [err_cores]="잘못된 코어 수입니다."
    [err_ram]="잘못된 RAM 용량입니다."
    [sec_disk]="데이터 디스크"
    [disk_bus_prompt]="VM의 디스크 버스 유형을 선택하세요."
    [sec_storage_mode]="스토리지 모드"
    [storage_mode_prompt]="VM이 데이터 디스크를 얻는 방식을 선택하세요."
    [mode_virtual]="가상 데이터 디스크 생성"
    [mode_passthrough]="물리 디스크 패스스루"
    [disk_size_prompt]="데이터 디스크 크기(GB)를 입력하세요"
    [err_disk_size]="잘못된 디스크 크기입니다."
    [storage_select_prompt]="데이터 디스크(%sG)를 저장할 스토리지를 선택하세요."
    [sec_passthrough]="디스크 패스스루"
    [pt_no_free_title]="사용 가능한 디스크 없음"
    [pt_no_free_body]="사용 중이지 않은 물리 디스크가 없습니다. (모든 디스크가 마운트됨/LVM·ZFS·RAID 구성원/부팅 디스크이거나 이미 VM에 연결되어 있습니다.)"
    [pt_heads_up_title]="참고"
    [pt_heads_up_body]="%s개 디스크는 사용 중으로 판단되어 숨겨졌습니다(부팅/LVM/ZFS/RAID/마운트 또는 VM 점유). 안전한 미사용 디스크만 표시됩니다."
    [pt_select_prompt]="패스스루할 물리 디스크를 선택하세요(스페이스로 토글):"
    [pt_nothing_title]="선택 없음"
    [pt_nothing_body]="최소 한 개의 디스크를 선택하거나, 뒤로 가서 가상 디스크를 선택하세요."
    [pt_confirm_title]="패스스루 확인"
    [pt_confirm_body]="다음 물리 디스크가 VM %s에 그대로 연결됩니다. 호스트나 다른 VM에서 사용 중이 아닌지 반드시 확인하세요 — 그렇지 않으면 데이터 손실이 발생할 수 있습니다.%s\n\n계속할까요?"
    [sec_storage]="스토리지"
    [sec_network]="네트워크"
    [storage_none_body]="콘텐츠 유형 '%s'에 사용 가능한 공간이 있는 적절한 스토리지를 찾지 못했습니다."
    [bridge_none_body]="활성 네트워크 브리지를 찾지 못했습니다."
    [network_select_prompt]="VM의 네트워크 브리지를 선택하세요."
    [sec_bootloader]="부트로더"
    [boot_prompt]="부트로더 이미지를 선택하세요"
    [boot_resolving]="%s 최신 버전을 확인하는 중..."
    [boot_net_err_title]="네트워크"
    [boot_net_err_body]="GitHub에 접속해 최신 버전을 확인할 수 없습니다. 연결을 확인하고 다시 시도하세요."
    [boot_empty_tag]="확인된 버전 태그가 비어 있습니다."
    [boot_url_err]="다운로드 URL을 생성할 수 없습니다."
    [createSerial]="가상 시리얼 포트를 추가할까요?"
    [createSerialDesc]="문제 발생 시 xterm.js로 접속하여 쉽게 확인할 수 있습니다."
    [serial_yes]="추가함"
    [serial_no]="추가 안 함"
    [sec_review]="검토 및 생성"
    [review_prompt]="설정을 검토한 뒤 VM을 생성하세요:"
    [review_create]="==> 지금 VM 생성 <=="
    [rev_vmid]="VM ID"
    [rev_vmname]="VM 이름"
    [rev_cores]="CPU 코어"
    [rev_ram]="RAM"
    [rev_bus]="디스크 버스"
    [rev_storage]="스토리지"
    [rev_bridge]="네트워크 브리지"
    [rev_bootloader]="부트로더"
    [rev_serial]="가상 시리얼 포트"
    [serial_enabled]="사용"
    [serial_disabled]="사용 안 함"
    [storage_line_virtual]="가상 %sG (%s)"
    [storage_line_passthrough]="패스스루 (%s개 디스크)"
    [pt_create_guard_title]="데이터 디스크 없음"
    [pt_create_guard_body]="패스스루 모드인데 선택된 물리 디스크가 없습니다. 스토리지를 수정해 디스크를 선택하거나 가상 디스크로 전환하세요."
    [dl_label]="%s %s 다운로드 중..."
    [dl_fail_title]="다운로드 실패"
    [dl_fail_body]="다운로드에 실패했습니다. 다시 시도할까요?"
    [extracting_title]="압축 해제"
    [extracting_body]="%s 이미지를 압축 해제하는 중..."
    [extract_fail_title]="압축 해제 실패"
    [extract_fail_body]="압축 해제 후 .img 파일을 찾지 못했습니다. 다시 시도할까요?"
    [vm_config_done]="VM 구성 완료!"
    [start_title]="VM을 시작할까요?"
    [start_body]="지금 새 가상 머신을 시작하시겠습니까?"
    [vm_create_failed]="VM 생성에 실패했습니다."
    [disk_attach_failed]="데이터 디스크 연결에 실패했습니다."
    [pt_attach_failed]="디스크 패스스루에 실패했습니다: %s"
    [serial_attach_failed]="가상 시리얼 포트 추가에 실패했습니다."
    [rollback_title]="롤백"
    [rollback_body]="부분 생성된 VM %s을(를) 삭제할까요?"
    [status_started]="시작됨"
    [status_not_started]="생성됨 (시작 안 함)"
    [summary_header]="--- VM 요약 ---"
    [sum_vmid]="VM ID: %s"
    [sum_vmname]="VM 이름: %s"
    [sum_status]="상태: %s"
    [sum_cores]="CPU 코어: %s"
    [sum_ram]="RAM: %s MB"
    [sum_bus]="디스크 버스: %s"
    [sum_network]="네트워크: %s"
    [sum_bootloader]="부트로더: %s %s (%s에서 연결)"
    [sum_serial]="가상 시리얼 포트: %s"
    [sum_data_passthrough]="데이터 디스크 (패스스루):"
    [sum_disk_item]="  - %s"
    [sum_data_virtual]="데이터 디스크: %sG (%s)"
    [summary_footer]="------------------"
    [sum_manage]="이제 Proxmox 웹 인터페이스에서 VM을 관리할 수 있습니다."
    [btn_back]="뒤로"
    [btn_cancel]="취소"
    [step_word]="단계"
)

# Return the current-language string for a key; fall back to English, then the key itself.
t() {
    local -n _tbl="MSG_${LANG_CHOICE}"
    if [[ -v _tbl[$1] ]]; then echo "${_tbl[$1]}"
    elif [[ -v MSG_en[$1] ]]; then echo "${MSG_en[$1]}"
    else echo "$1"; fi
}
# printf template: tf <key> [args...]
tf() { local _k="$1"; shift; printf "$(t "$_k")" "$@"; }

# --- Helper Functions ---

# Display a message with a color
msg() {
    local text="$1"
    local color="$2"
    echo -e "${color}${text}${N}"
}

# Install necessary packages if they are not installed
install_package() {
    if ! dpkg -s "$1" &>/dev/null;
    then
        msg "Installing $1..." "$Y"
        apt-get update >/dev/null
        apt-get install -y "$1" >/dev/null
    fi
}

# --- Pure logic helpers (no whiptail / no network; unit-tested) ---

# Map a bootloader image name to its GitHub repo.
bootloader_repo() {
    case "$1" in
        m-shell) echo "PeterSuh-Q3/tinycore-redpill" ;;
        RR)      echo "RROrg/rr" ;;
        *)       return 1 ;;
    esac
}

# Build the release asset URL for a given image name + tag.
build_img_url() {
    local name="$1" tag="$2"
    case "$name" in
        m-shell) echo "https://github.com/PeterSuh-Q3/tinycore-redpill/releases/download/${tag}/alpine-redpill.${tag}.m-shell.img.gz" ;;
        RR)      echo "https://github.com/RROrg/rr/releases/download/${tag}/rr-${tag}.img.zip" ;;
        *)       return 1 ;;
    esac
}

# Clamped integer percent of cur/total (0..100); 0 when total is unknown/zero.
gauge_pct() {  # cur total
    local cur="$1" total="$2" p
    [[ "$total" =~ ^[0-9]+$ ]] && (( total > 0 )) || { echo 0; return; }
    p=$(( cur * 100 / total ))
    (( p > 100 )) && p=100
    (( p < 0 )) && p=0
    echo "$p"
}


# Read disks/list JSON on stdin; emit "by_id_link \t model size (serial)" for unused disks only.
parse_disks() {
    "$JQ_CMD" -r '
        .[]
        | select((.used // "") == "")
        | select((.by_id_link // "") != "")
        | (.size // 0) as $b
        | (if $b >= 1099511627776 then (($b/1099511627776)*10|floor/10|tostring)+"T"
           else (($b/1073741824)*10|floor/10|tostring)+"G" end) as $sz
        | .by_id_link + "\t" + ((.model // "disk")|gsub("^ +| +$";"")) + " " + $sz + " (" + (.serial // "?") + ")"
    '
}

# --- Proxmox API Functions using whiptail ---

# Echoes chosen storage on stdout; rc 0=OK, 1=Back, 3=no-storage-error.
select_storage() {
    local prompt_text=$1 content_type=$2 default_item=$3
    local whiptail_options=()
    while IFS=$'\t' read -r name desc; do
        whiptail_options+=("$name" "$desc")
    done < <(pvesh get /nodes/$(hostname)/storage --output-format json | "$JQ_CMD" -r '
        .[] |
        select(
            (has("disable") | not) and
            (.content | contains("'"$content_type"'")) and
            .type != "nfs" and .type != "cifs" and
            has("total") and has("avail") and .avail > 0
        ) |
        .storage + "\t" + "[" + .type + "] " + ((.avail / 1073741824) | tostring | .[0:5]) + "G / " + ((.total / 1073741824) | tostring | .[0:5]) + "G"
    ')
    if [ ${#whiptail_options[@]} -eq 0 ]; then
        wt_msg "$(t sec_storage)" "$(tf storage_none_body "$content_type")"
        return 3
    fi
    local out
    out=$(whiptail --backtitle "$BACKTITLE" --title "$(_wt_title "$(t sec_storage)")" \
        --cancel-button "$(_wt_cancel_label)" --default-item "$default_item" \
        --menu "$prompt_text" 20 78 10 "${whiptail_options[@]}" 3>&1 1>&2 2>&3)
    local rc=$?
    echo "$out"
    case $rc in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
}

# Echoes chosen bridge on stdout; rc 0=OK, 1=Back, 3=no-bridge-error.
select_bridge() {
    local prompt_text=$1 default_item=$2
    local whiptail_options=()
    while IFS=$'\t' read -r name desc; do
        whiptail_options+=("$name" "$desc")
    done < <(pvesh get /nodes/$(hostname)/network --output-format json | "$JQ_CMD" -r '.[] | select(.type == "bridge" and (has("disable") | not)) | .iface + "\t" + (.cidr // "no CIDR")')
    if [ ${#whiptail_options[@]} -eq 0 ]; then
        wt_msg "$(t sec_network)" "$(t bridge_none_body)"
        return 3
    fi
    local out
    out=$(whiptail --backtitle "$BACKTITLE" --title "$(_wt_title "$(t sec_network)")" \
        --cancel-button "$(_wt_cancel_label)" --default-item "$default_item" \
        --menu "$prompt_text" 20 78 10 "${whiptail_options[@]}" 3>&1 1>&2 2>&3)
    local rc=$?
    echo "$out"
    case $rc in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
}

# Resolve the single 'latest' tag via the releases/latest redirect. rc 1 on failure.
fetch_latest_tag() {
    local repo="$1" url
    url=$(curl -sfL -w '%{url_effective}' -o /dev/null "https://github.com/${repo}/releases/latest") || return $?
    echo "${url##*/}"
}

# --- Physical disk safety helpers (passthrough) ---

# True (rc 0) if a whole disk or any of its partitions is mounted or a member of LVM/ZFS/MD/swap.
disk_in_use() {  # $1 = /dev/sdX
    # Mounted? (whole disk or any partition). Single-column query avoids lsblk -r field collapse.
    if lsblk -nro MOUNTPOINT "$1" 2>/dev/null | grep -q .; then
        return 0
    fi
    # Member of LVM / ZFS / MD, or swap?
    if lsblk -nro FSTYPE "$1" 2>/dev/null | grep -Eq 'LVM2_member|zfs_member|linux_raid_member|swap'; then
        return 0
    fi
    return 1
}

# True (rc 0) if the by-id path already appears in any VM config.
disk_claimed_by_vm() {  # $1 = by-id path
    grep -qs -- "$1" /etc/pve/qemu-server/*.conf 2>/dev/null
}

# Emit "by_id \t label" for disks safe to pass through. Combines parse_disks (used filter)
# with live checks: exclude the root disk, mounted/member disks, and disks claimed by a VM.
passthrough_candidates() {
    local rootsrc rootdisk
    rootsrc=$(findmnt -no SOURCE / 2>/dev/null)
    rootdisk=$(lsblk -no PKNAME "$rootsrc" 2>/dev/null | head -1)   # e.g. "sda"
    local byid label devpath
    while IFS=$'\t' read -r byid label; do
        [ -z "$byid" ] && continue
        devpath=$(readlink -f "$byid" 2>/dev/null)
        [ -z "$devpath" ] && continue
        [ -n "$rootdisk" ] && [ "$(basename "$devpath")" = "$rootdisk" ] && continue
        disk_in_use "$devpath" && continue
        disk_claimed_by_vm "$byid" && continue
        printf '%s\t%s\n' "$byid" "$label"
    done < <(pvesh get /nodes/$(hostname)/disks/list --output-format json | parse_disks)
}


# --- whiptail wrappers (consistent branding + button labels) ---

# Title like "Step 2/5 · Data Disk"
_wt_title() { echo "$(t step_word) ${CURRENT_STEP}/${STEP_TOTAL} · $1"; }

# Back button label: first step shows "Cancel", later steps show "Back".
_wt_cancel_label() { (( CURRENT_STEP <= 1 )) && echo "$(t btn_cancel)" || echo "$(t btn_back)"; }

# Input box. Args: section_title, prompt, default. Echoes value. rc 0=OK, 1=Back/Cancel.
wt_input() {
    local title="$1" prompt="$2" default="$3" out
    out=$(whiptail --backtitle "$BACKTITLE" --title "$(_wt_title "$title")" \
        --cancel-button "$(_wt_cancel_label)" \
        --inputbox "$prompt" 10 70 "$default" 3>&1 1>&2 2>&3)
    local rc=$?
    echo "$out"
    case $rc in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
}

# Menu. Args: section_title, prompt, default_item, then (tag label) pairs. Echoes tag. rc 0=OK,1=Back.
wt_menu() {
    local title="$1" prompt="$2" default_item="$3"; shift 3
    local out
    out=$(whiptail --backtitle "$BACKTITLE" --title "$(_wt_title "$title")" \
        --cancel-button "$(_wt_cancel_label)" \
        --default-item "$default_item" \
        --menu "$prompt" 20 78 10 "$@" 3>&1 1>&2 2>&3)
    local rc=$?
    echo "$out"
    case $rc in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
}

# Checklist (multi-select). Args: section_title, prompt, then (tag label status) triples.
# Echoes space-separated quoted tags chosen. rc 0=OK, 1=Back. Nothing is preselected by callers.
wt_checklist() {
    local title="$1" prompt="$2"; shift 2
    local out
    out=$(whiptail --backtitle "$BACKTITLE" --title "$(_wt_title "$title")" \
        --cancel-button "$(_wt_cancel_label)" \
        --checklist "$prompt" 20 78 10 "$@" 3>&1 1>&2 2>&3)
    local rc=$?
    echo "$out"
    case $rc in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
}

# Message box.
wt_msg() {
    whiptail --backtitle "$BACKTITLE" --title "$1" --msgbox "$2" "${3:-12}" "${4:-70}"
}

# Yes/No. rc 0=yes, 1=no.
wt_yesno() {
    whiptail --backtitle "$BACKTITLE" --title "$1" --yesno "$2" "${3:-10}" "${4:-70}"
}

# Transient info (no buttons).
wt_infobox() {
    whiptail --backtitle "$BACKTITLE" --title "$1" --infobox "$2" "${3:-8}" "${4:-70}"
}

# Download with a whiptail progress gauge driven by downloaded bytes vs the
# Content-Length read from the GET response headers (no separate HEAD needed).
# curl's own meter is suppressed so nothing leaks onto the TUI.
# Args: url, dest, label. rc 0 on success, non-zero on curl failure.
download_with_gauge() {
    local url="$1" dest="$2" label="$3" rc cpid cur total hdr
    hdr=$(mktemp)
    rm -f "$dest"
    curl --fail -kL -o "$dest" -D "$hdr" "$url" 2>/dev/null &
    cpid=$!
    {
        total=0
        while kill -0 "$cpid" 2>/dev/null; do
            if (( total == 0 )) && [ -s "$hdr" ]; then
                # mawk-safe, case-insensitive; last Content-Length wins (after redirects).
                total=$(awk 'tolower($1)=="content-length:"{v=$2} END{gsub(/[^0-9]/,"",v); print v+0}' "$hdr")
            fi
            cur=$(stat -c %s "$dest" 2>/dev/null || echo 0)
            gauge_pct "$cur" "$total"
            sleep 0.3
        done
        echo 100
    } | whiptail --backtitle "$BACKTITLE" --gauge "$label" 8 70 0
    wait "$cpid"; rc=$?
    rm -f "$hdr"
    return $rc
}


# --- Step functions: rc 0=next, 1=back, 2=cancel, 100=redisplay ---

step_core() {
    local new_vmid new_vmname new_cores new_ram
    new_vmid=$(wt_input "$(t sec_core)" "$(t core_vmid_prompt)" "${VMID:-$(pvesh get /cluster/nextid)}") || return $?
    [ -n "$new_vmid" ] || { wt_msg "$(t err_title)" "$(t err_vmid_empty)"; return 100; }
    [[ "$new_vmid" =~ ^[0-9]+$ ]] || { wt_msg "$(t err_title)" "$(t err_vmid)"; return 100; }
    new_vmname=$(wt_input "$(t sec_core)" "$(t core_vmname_prompt)" "${VMNAME:-Xpenology}") || return $?
    [ -n "$new_vmname" ] || { wt_msg "$(t err_title)" "$(t err_vmname_empty)"; return 100; }
    new_cores=$(wt_input "$(t sec_core)" "$(t core_cores_prompt)" "${CORES:-2}") || return $?
    [[ "$new_cores" =~ ^[0-9]+$ ]] || { wt_msg "$(t err_title)" "$(t err_cores)"; return 100; }
    new_ram=$(wt_input "$(t sec_core)" "$(t core_ram_prompt)" "${RAM:-4096}") || return $?
    [[ "$new_ram" =~ ^[0-9]+$ ]] || { wt_msg "$(t err_title)" "$(t err_ram)"; return 100; }
    VMID="$new_vmid"
    VMNAME="$new_vmname"
    CORES="$new_cores"
    RAM="$new_ram"
    return 0
}

step_storage() {
    local choice default_bus
    case "$BUS_TYPE_PARAM" in scsi) default_bus=1 ;; sata) default_bus=2 ;; *) default_bus=1 ;; esac
    choice=$(wt_menu "$(t sec_disk)" "$(t disk_bus_prompt)" "$default_bus" \
        "1" "VirtIO SCSI (DS3622xs+)" \
        "2" "SATA (SA6400, DS920+, etc)") || return $?
    case $choice in
        1) BUS_TYPE_PARAM="scsi" ;;
        2) BUS_TYPE_PARAM="sata" ;;
        *) return 100 ;;
    esac

    local mode_default
    case "$STORAGE_MODE" in passthrough) mode_default="passthrough" ;; *) mode_default="virtual" ;; esac
    local mode
    mode=$(wt_menu "$(t sec_storage_mode)" "$(t storage_mode_prompt)" "$mode_default" \
        "virtual"     "$(t mode_virtual)" \
        "passthrough" "$(t mode_passthrough)") || return $?
    case "$mode" in
        virtual)     STORAGE_MODE="virtual";     step_storage_virtual ;;
        passthrough) STORAGE_MODE="passthrough"; step_storage_passthrough ;;
        *) return 100 ;;
    esac
}

step_storage_virtual() {
    DISK_SIZE=$(wt_input "$(t sec_disk)" "$(t disk_size_prompt)" "${DISK_SIZE:-32}") || return $?
    [[ "$DISK_SIZE" =~ ^[0-9]+$ ]] || { wt_msg "$(t err_title)" "$(t err_disk_size)"; return 100; }
    DATA_STORAGE=$(select_storage "$(tf storage_select_prompt "$DISK_SIZE")" "images" "$DATA_STORAGE")
    case $? in 0) ;; 1) return 1 ;; 2) return 2 ;; *) return 100 ;; esac
    return 0
}

step_storage_passthrough() {
    local opts=() byid label total=0 shown=0
    while IFS=$'\t' read -r byid label; do
        [ -z "$byid" ] && continue
        opts+=("$byid" "$label" "off")
        shown=$((shown + 1))
    done < <(passthrough_candidates)
    total=$(pvesh get /nodes/$(hostname)/disks/list --output-format json | "$JQ_CMD" -r 'length')
    if (( shown == 0 )); then
        wt_msg "$(t pt_no_free_title)" "$(t pt_no_free_body)"
        return 100
    fi
    if (( total > shown )); then
        wt_msg "$(t pt_heads_up_title)" "$(tf pt_heads_up_body "$((total - shown))")"
    fi
    local selected
    selected=$(wt_checklist "$(t sec_passthrough)" "$(t pt_select_prompt)" "${opts[@]}") || return $?
    [ -n "$selected" ] || { wt_msg "$(t pt_nothing_title)" "$(t pt_nothing_body)"; return 100; }
    PASSTHRU_DISKS=()
    eval "PASSTHRU_DISKS=($selected)"
    local list="" d
    for d in "${PASSTHRU_DISKS[@]}"; do list+=$'\n'"  • $d"; done
    if ! wt_yesno "$(t pt_confirm_title)" "$(tf pt_confirm_body "$VMID" "$list")" 18 74; then
        return 100
    fi
    return 0
}

step_network() {
    BRIDGE=$(select_bridge "$(t network_select_prompt)" "$BRIDGE")
    case $? in 0) ;; 1) return 1 ;; 2) return 2 ;; *) return 100 ;; esac
    return 0
}

step_bootloader() {
    local kind_default
    case "$IMAGE_NAME" in m-shell) kind_default=1 ;; RR) kind_default=2 ;; *) kind_default=1 ;; esac
    local choice
    choice=$(wt_menu "$(t sec_bootloader)" "$(t boot_prompt)" "$kind_default" \
        "1" "m-shell" "2" "RR") || return $?
    case $choice in
        1) IMAGE_NAME="m-shell" ;;
        2) IMAGE_NAME="RR" ;;
        *) return 100 ;;
    esac

    local repo
    repo=$(bootloader_repo "$IMAGE_NAME")
    wt_infobox "$(t sec_bootloader)" "$(tf boot_resolving "$IMAGE_NAME")"
    IMG_TAG=$(fetch_latest_tag "$repo") || { wt_msg "$(t boot_net_err_title)" "$(t boot_net_err_body)"; return 100; }
    [ -n "$IMG_TAG" ] || { wt_msg "$(t err_generic)" "$(t boot_empty_tag)"; return 100; }
    IMG_URL=$(build_img_url "$IMAGE_NAME" "$IMG_TAG") || { wt_msg "$(t err_generic)" "$(t boot_url_err)"; return 100; }

    prepare_bootloader || return $?00
    return 0
}

step_serial() {
    local default_choice choice rc
    case "$CREATE_SERIAL" in
        0) default_choice="no" ;;
        *) default_choice="yes" ;;
    esac
    choice=$(whiptail --backtitle "$BACKTITLE" --title "$(_wt_title "$(t createSerial)")" \
        --cancel-button "$(_wt_cancel_label)" --default-item "$default_choice" --notags \
        --menu "$(t createSerialDesc)" 20 78 10 \
        "yes" "$(t serial_yes)" \
        "no"  "$(t serial_no)" 3>&1 1>&2 2>&3)
    rc=$?
    case $rc in 0) ;; 1) return 1 ;; *) return 2 ;; esac
    case "$choice" in
        yes) CREATE_SERIAL=1 ;;
        no)  CREATE_SERIAL=0 ;;
        *) return 100 ;;
    esac
    return 0
}

step_confirm() {
    local choice storage_line serial_line
    while true; do
        if [ "$STORAGE_MODE" = "passthrough" ]; then
            storage_line="$(t rev_storage): $(tf storage_line_passthrough "${#PASSTHRU_DISKS[@]}")"
        else
            storage_line="$(t rev_storage): $(tf storage_line_virtual "$DISK_SIZE" "$DATA_STORAGE")"
        fi
        if (( CREATE_SERIAL )); then
            serial_line="$(t rev_serial): $(t serial_enabled)"
        else
            serial_line="$(t rev_serial): $(t serial_disabled)"
        fi
        choice=$(whiptail --backtitle "$BACKTITLE" --title "$(_wt_title "$(t sec_review)")" \
            --cancel-button "$(t btn_back)" \
            --menu "$(t review_prompt)" 22 78 12 \
            "create"  "$(t review_create)" \
            "VMID"    "$(t rev_vmid): ${VMID}" \
            "VMNAME"  "$(t rev_vmname): ${VMNAME}" \
            "CORES"   "$(t rev_cores): ${CORES}" \
            "RAM"     "$(t rev_ram): ${RAM} MB" \
            "BUS"     "$(t rev_bus): ${BUS_TYPE_PARAM}" \
            "STORAGE" "$storage_line" \
            "BRIDGE"  "$(t rev_bridge): ${BRIDGE}" \
            "BOOT"    "$(t rev_bootloader): ${IMAGE_NAME} ${IMG_TAG}" \
            "SERIAL"  "$serial_line" \
            3>&1 1>&2 2>&3)
        case $? in 0) ;; 255) return 2 ;; *) return 1 ;; esac
        case "$choice" in
            create)
                if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
                    wt_msg "$(t err_title)" "$(t err_vmid)"
                    step_core
                    continue
                fi
                if [ "$STORAGE_MODE" = "passthrough" ] && (( ${#PASSTHRU_DISKS[@]} == 0 )); then
                    wt_msg "$(t pt_create_guard_title)" "$(t pt_create_guard_body)"
                    continue
                fi
                return 0
                ;;
            VMID|VMNAME|CORES|RAM) step_core ;;
            BUS|STORAGE)           step_storage ;;
            BRIDGE)                step_network ;;
            BOOT)                  step_bootloader ;;
            SERIAL)                step_serial ;;
        esac
    done
}


# --- Lifecycle ---

BOOTLOADER_DIR="/var/lib/vz/template/iso"
IMG_PATH=""   # set in prepare_bootloader

cleanup() {
    rm -f "${BOOTLOADER_DIR}/${IMAGE_NAME}-${VMID}.img.gz" \
          "${BOOTLOADER_DIR}/${IMAGE_NAME}-${VMID}.img.zip" \
          "${BOOTLOADER_DIR}/rr.img" "${BOOTLOADER_DIR}/sha256sum" 2>/dev/null
}

abort() {
    cleanup
    msg "$(t canceled)" "$R"
    exit 1
}

# Esc anywhere in the wizard -> ask to quit. rc 0 if the user chose to quit.
confirm_quit() {
    wt_yesno "$(t quit_title)" "$(t quit_body)"
}

# One-time language selection shown before the wizard. Cancel/Esc = quit.
pick_language() {
    local choice
    choice=$(whiptail --backtitle "$BACKTITLE" --title "Language / 언어" \
        --menu "Select your language / 언어를 선택하세요" 12 60 2 \
        "en" "English" \
        "ko" "한국어" 3>&1 1>&2 2>&3) || abort
    LANG_CHOICE="$choice"
    BACKTITLE="$(t backtitle)"
}

# Download + extract the selected bootloader. rc 0 on success.
prepare_bootloader() {
    mkdir -p "$BOOTLOADER_DIR"
    IMG_PATH="${BOOTLOADER_DIR}/${IMAGE_NAME}-${VMID}.img"
    while true; do
        if [[ "$IMG_URL" == *.zip ]]; then
            download_with_gauge "$IMG_URL" "${IMG_PATH}.zip" "$(tf dl_label "$IMAGE_NAME" "$IMG_TAG")"
        else
            download_with_gauge "$IMG_URL" "${IMG_PATH}.gz" "$(tf dl_label "$IMAGE_NAME" "$IMG_TAG")"
        fi
        if (( $? != 0 )); then
            if wt_yesno "$(t dl_fail_title)" "$(t dl_fail_body)"; then continue; else cleanup; return 1; fi
        fi
        wt_infobox "$(t extracting_title)" "$(tf extracting_body "$IMAGE_NAME")"
        if [[ "$IMG_URL" == *.zip ]]; then
            unzip -o "${IMG_PATH}.zip" -d "$BOOTLOADER_DIR" >/dev/null 2>&1
            [ -f "${BOOTLOADER_DIR}/rr.img" ] && mv "${BOOTLOADER_DIR}/rr.img" "$IMG_PATH"
        else
            gunzip -f "${IMG_PATH}.gz"
        fi
        cleanup
        if [ -f "$IMG_PATH" ]; then return 0; fi
        if ! wt_yesno "$(t extract_fail_title)" "$(t extract_fail_body)"; then return 1; fi
    done
}

# Create + configure the VM. Offers rollback on failure.
create_vm() {
    if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
        wt_msg "$(t err_title)" "$(t err_vmid)"
        return 1
    fi
    wt_infobox "$(t sec_review)" "$(tf creating_vm "$VMID")"
    if ! qm create "$VMID" --name "$VMNAME" --memory "$RAM" --cores "$CORES" --bios seabios --ostype l26; then
        rollback "$(t vm_create_failed)"; exit 1
    fi
    if [ "$BUS_TYPE_PARAM" == "scsi" ]; then qm set "$VMID" --scsihw virtio-scsi-pci; fi
    if [ "$STORAGE_MODE" = "passthrough" ]; then
        local idx=0 disk
        for disk in "${PASSTHRU_DISKS[@]}"; do
            if ! qm set "$VMID" --"${BUS_TYPE_PARAM}${idx}" "$disk"; then
                rollback "$(tf pt_attach_failed "$disk")"; exit 1
            fi
            (( idx++ ))
        done
    else
        if ! qm set "$VMID" --"${BUS_TYPE_PARAM}0" "${DATA_STORAGE}:${DISK_SIZE},discard=on,ssd=1"; then
            rollback "$(t disk_attach_failed)"; exit 1
        fi
    fi
    if (( CREATE_SERIAL )) && ! qm set "$VMID" --serial0 socket; then
        rollback "$(t serial_attach_failed)"; exit 1
    fi
    qm set "$VMID" --net0 virtio,bridge="$BRIDGE"
    local qm_args="-drive if=none,id=synoboot,format=raw,file=${IMG_PATH} -device qemu-xhci,id=xhci -device usb-storage,bus=xhci.0,drive=synoboot,bootindex=0"
    qm set "$VMID" --args "$qm_args"
    msg "$(t vm_config_done)" "$G"

    if wt_yesno "$(t start_title)" "$(t start_body)"; then
        qm start "$VMID"; VM_STATUS="$(t status_started)"
    else
        VM_STATUS="$(t status_not_started)"
    fi
    print_summary
}

rollback() {  # message
    wt_msg "$(t err_generic)" "$1"
    if wt_yesno "$(t rollback_title)" "$(tf rollback_body "$VMID")"; then
        qm destroy "$VMID" --purge 2>/dev/null
    fi
}

print_summary() {
    msg "$(t summary_header)" "$B"
    msg "$(tf sum_vmid "$VMID")" "$G"
    msg "$(tf sum_vmname "$VMNAME")" "$G"
    msg "$(tf sum_status "$VM_STATUS")" "$G"
    msg "$(tf sum_cores "$CORES")" "$G"
    msg "$(tf sum_ram "$RAM")" "$G"
    msg "$(tf sum_bus "$BUS_TYPE_PARAM")" "$G"
    msg "$(tf sum_network "$BRIDGE")" "$G"
    msg "$(tf sum_bootloader "$IMAGE_NAME" "$IMG_TAG" "$IMG_PATH")" "$G"
    if (( CREATE_SERIAL )); then
        msg "$(tf sum_serial "$(t serial_enabled)")" "$G"
    else
        msg "$(tf sum_serial "$(t serial_disabled)")" "$G"
    fi
    if [ "$STORAGE_MODE" = "passthrough" ]; then
        msg "$(t sum_data_passthrough)" "$G"
        local d
        for d in "${PASSTHRU_DISKS[@]}"; do msg "$(tf sum_disk_item "$d")" "$G"; done
    else
        msg "$(tf sum_data_virtual "$DISK_SIZE" "$DATA_STORAGE")" "$G"
    fi
    msg "$(t summary_footer)" "$B"
    msg "$(t sum_manage)" "$Y"
}


# --- Main Logic ---

main() {
    if [ "$(id -u)" -ne 0 ]; then msg "$(t root_err)" "$R"; exit 1; fi
    install_package "jq";       JQ_CMD=$(which jq)
    install_package "unzip"
    install_package "whiptail"

    # Wizard state (declared here so a re-run starts clean).
    LANG_CHOICE="en"
    BACKTITLE="$(t backtitle)"
    STORAGE_MODE="virtual"; PASSTHRU_DISKS=()
    CREATE_SERIAL=1
    trap cleanup EXIT
    trap 'exit 130' INT TERM
    pick_language

    local steps=(step_core step_storage step_network step_bootloader step_serial step_confirm)
    local i=0
    while (( i >= 0 && i < ${#steps[@]} )); do
        CURRENT_STEP=$(( i + 1 ))
        "${steps[$i]}"; local rc=$?
        case $rc in
            0)   (( i++ )) ;;
            1)   (( i-- )) ;;
            2)   confirm_quit && abort ;;
            100) ;;
        esac
        if (( i < 0 )); then abort; fi
    done
    create_vm
}

# Only run the wizard when executed directly, not when sourced by tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
