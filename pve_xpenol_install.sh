#!/bin/bash

# Color Palette
G='\033[1;32m'
R='\033[0;31m'
B='\033[0;34m'
Y='\033[0;33m'
N='\033[0m'

# --- Helper Functions ---

# Display a message with a color
msg() {
    local text="$1"
    local color="$2"
    echo -e "${color}${text}${N}"
}

# Find the absolute path to jq to avoid PATH issues
JQ_CMD=$(which jq)
if [ -z "$JQ_CMD" ]; then
    msg "jq command not found. Please install jq and ensure it's in your PATH." "$R"
    exit 1
fi

# Install necessary packages if they are not installed
install_package() {
    if ! dpkg -s "$1" &>/dev/null;
    then
        msg "Installing $1..." "$Y"
        apt-get update >/dev/null
        apt-get install -y "$1" >/dev/null
    fi
}

# --- Proxmox API Functions using whiptail ---

# Get available storages and let the user choose
select_storage() {
    local prompt_text=$1
    local content_type=$2
    local whiptail_options=()

    # ENHANCEMENT: Filter out storages with 0 available space
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
        whiptail --msgbox "No suitable storage with available space found for content type '$content_type'." 10 70
        exit 1
    fi

    selected_storage=$(whiptail --title "Storage Selection" --menu "$prompt_text" 20 78 10 "${whiptail_options[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi

    echo "$selected_storage"
}

# Get available network bridges and let the user choose
select_bridge() {
    local prompt_text=$1
    local whiptail_options=()

    while IFS=$'\t' read -r name desc; do
        whiptail_options+=("$name" "$desc")
    done < <(pvesh get /nodes/$(hostname)/network --output-format json | "$JQ_CMD" -r '.[] | select(.type == "bridge" and (has("disable") | not)) | .iface + "\t" + (.cidr // "no CIDR")')

    if [ ${#whiptail_options[@]} -eq 0 ]; then
        whiptail --msgbox "No active network bridge found." 10 60
        exit 1
    fi

    selected_bridge=$(whiptail --title "Network Selection" --menu "$prompt_text" 20 78 10 "${whiptail_options[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi

    echo "$selected_bridge"
}


# --- Main Logic ---

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    msg "This script must be run as root." "$R"
    exit 1
fi

# Install dependencies
install_package "unzip"
install_package "whiptail"


# --- Script Flow Step 1: Core VM Config ---
whiptail --title "Step 1: Core VM Configuration" --msgbox "This step configures the basic information for the virtual machine.\n\nYou will enter the ID, Name, number of CPU cores, and Memory (RAM) in sequence." 10 70
if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi

VMID=$(whiptail --inputbox "Enter VM ID" 10 60 "$(pvesh get /cluster/nextid)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ] || [ -z "$VMID" ]; then msg "Canceled or VM ID empty." "$R"; exit 1; fi

VMNAME=$(whiptail --inputbox "Enter VM Name" 10 60 "Xpenology" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ] || [ -z "$VMNAME" ]; then msg "Canceled or VM Name empty." "$R"; exit 1; fi

CORES=$(whiptail --inputbox "Enter CPU Cores" 10 60 "2" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi
if ! [[ "$CORES" =~ ^[0-9]+$ ]]; then msg "Invalid number of cores." "$R"; exit 1; fi

RAM=$(whiptail --inputbox "Enter RAM in MB" 10 60 "2048" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi
if ! [[ "$RAM" =~ ^[0-9]+$ ]]; then msg "Invalid RAM size." "$R"; exit 1; fi


# --- Script Flow Step 2: Storage Config ---
whiptail --title "Step 2: Data Disk Configuration" --msgbox "This step configures the VM's main data disk.\n\nYou will select the disk bus type, disk capacity, and the storage where the disk will be created." 10 70
if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi

BUS_CHOICE=$(whiptail --title "Disk Bus Type" --menu "Select the disk bus type for the VM." 15 60 2 \
"1" "VirtIO SCSI (DS3622xs+)" \
"2" "SATA (SA6400, DS920+, etc)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi

case $BUS_CHOICE in
    1) BUS_TYPE_PARAM="scsi";;
    2) BUS_TYPE_PARAM="sata";;
    *) msg "Invalid choice. Exiting." "$R"; exit 1;;
esac

DISK_SIZE=$(whiptail --inputbox "Enter Data Disk Size in GB" 10 60 "32" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi
if ! [[ "$DISK_SIZE" =~ ^[0-9]+$ ]]; then msg "Invalid disk size." "$R"; exit 1; fi

DATA_STORAGE=$(select_storage "Please select the storage for the DATA disk (${DISK_SIZE}G)." "images")


# --- Script Flow Step 3: Network Config ---
whiptail --title "Step 3: Network Configuration" --msgbox "This step selects the network bridge for the virtual machine.\n\nThis is typically 'vmbr0'." 10 70
if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi
BRIDGE=$(select_bridge "Please select the network bridge for the VM.")


# --- Script Flow Step 4: Bootloader Selection and Preparation ---
whiptail --title "Step 4: Bootloader Configuration" --msgbox "Finally, select the bootloader type for Xpenology.\n\nThe selected bootloader will be stored on Proxmox 'local' storage and attached as a virtual USB drive." 12 70
if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi
IMAGE_CHOICE=$(whiptail --menu "Choose a bootloader image" 15 60 4 \
"1" "m-shell" \
"2" "RR" \
"3" "xTCRP" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then msg "Canceled." "$R"; exit 1; fi

case $IMAGE_CHOICE in
    1) IMAGE_NAME="m-shell"; LATESTURL=$(curl -sL -w %{url_effective} -o /dev/null "https://github.com/PeterSuh-Q3/tinycore-redpill/releases/latest"); TAG="${LATESTURL##*/}"; IMG_URL="https://github.com/PeterSuh-Q3/tinycore-redpill/releases/download/${TAG}/tinycore-redpill.${TAG}.m-shell.img.gz";;
    2) IMAGE_NAME="RR"; LATESTURL=$(curl -sL -w %{url_effective} -o /dev/null "https://github.com/RROrg/rr/releases/latest"); TAG="${LATESTURL##*/}"; IMG_URL="https://github.com/RROrg/rr/releases/download/${TAG}/rr-${TAG}.img.zip";;
    3) IMAGE_NAME="xTCRP"; LATESTURL=$(curl -sL -w %{url_effective} -o /dev/null "https://github.com/PeterSuh-Q3/tinycore-redpill/releases/latest"); TAG="${LATESTURL##*/}"; IMG_URL="https://github.com/PeterSuh-Q3/tinycore-redpill/releases/download/${TAG}/tinycore-redpill.${TAG}.xtcrp.img.gz";;
    *) msg "Invalid choice. Exiting." "$R"; exit 1;;
esac

BOOTLOADER_DIR="/var/lib/vz/template/iso"
mkdir -p "$BOOTLOADER_DIR"
IMG_PATH="${BOOTLOADER_DIR}/${IMAGE_NAME}-${VMID}.img"

trap 'rm -f "${BOOTLOADER_DIR}/${IMAGE_NAME}-${VMID}.img.gz" "${BOOTLOADER_DIR}/${IMAGE_NAME}-${VMID}.img.zip" "${BOOTLOADER_DIR}/rr.img" "${BOOTLOADER_DIR}/sha256sum"' EXIT

msg "Downloading and preparing ${IMAGE_NAME} image to ${IMG_PATH}..." "$Y"
if [[ "$IMG_URL" == *.zip ]]; then
    curl -kL# "$IMG_URL" -o "${IMG_PATH}.zip"
    unzip -o "${IMG_PATH}.zip" -d "$BOOTLOADER_DIR"
    # BUG FIX: Explicitly find and rename 'rr.img'
    if [ -f "${BOOTLOADER_DIR}/rr.img" ]; then
        mv "${BOOTLOADER_DIR}/rr.img" "$IMG_PATH"
    fi
else
    curl -kL# "$IMG_URL" -o "${IMG_PATH}.gz"
    gunzip -f "${IMG_PATH}.gz"
fi

if [ ! -f "$IMG_PATH" ]; then
    msg "Could not find .img file after download and extraction." "$R"; exit 1;
fi

# --- Script Flow Step 5: Final VM Creation and Configuration ---
msg "Step 5: Creating and configuring VM ${VMID}..." "$Y"
qm create "$VMID" --name "$VMNAME" --memory "$RAM" --cores "$CORES" --net0 virtio,bridge="$BRIDGE" --bios seabios --ostype l26
if [ $? -ne 0 ]; then msg "Failed to create VM." "$R"; exit 1; fi

if [ "$BUS_TYPE_PARAM" == "scsi" ]; then
    qm set "$VMID" --scsihw virtio-scsi-pci
fi

qm set "$VMID" --"${BUS_TYPE_PARAM}1" "${DATA_STORAGE}:${DISK_SIZE},discard=on,ssd=1"
msg "Attaching bootloader as a virtual USB drive..." "$Y"
QM_ARGS="-drive if=none,id=synoboot,format=raw,file=${IMG_PATH} -device qemu-xhci,id=xhci -device usb-storage,bus=xhci.0,drive=synoboot,bootindex=1"
qm set "$VMID" --args "$QM_ARGS"

msg "VM configuration complete!" "$G"

# --- Ask to start VM ---
if (whiptail --title "Start VM?" --yesno "Would you like to start the new virtual machine now?" 10 60) then
    msg "Starting VM ${VMID}..." "$Y"
    qm start "$VMID"
    VM_STATUS="Started"
else
    VM_STATUS="Created (Not Started)"
fi

# --- Final Summary ---
whiptail --title "All Done!" --msgbox "Virtual machine creation process is complete.\n\nPlease check the summary information printed in the terminal below." 10 70

msg "--- VM Summary ---" "$B"
msg "VM ID: $VMID" "$G"
msg "VM Name: $VMNAME" "$G"
msg "Status: $VM_STATUS" "$G"
msg "CPU Cores: $CORES" "$G"
msg "RAM: $RAM MB" "$G"
msg "Disk Bus: $BUS_TYPE_PARAM" "$G"
msg "Network: $BRIDGE" "$G"
msg "Bootloader: Attached directly from ${IMG_PATH}" "$G"
msg "Data Disk: ${DISK_SIZE}G on $DATA_STORAGE" "$G"
msg "------------------" "$B"
msg "You can now manage the VM from the Proxmox web interface." "$Y"
