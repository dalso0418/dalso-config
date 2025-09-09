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

# Get available VMs and let the user choose
select_vm() {
    local prompt_text=$1
    local whiptail_options=()

    # Get VM list without any extra output
    while read -r line; do
        # Skip header line
        if [[ "$line" =~ ^VMID ]]; then
            continue
        fi
        # Look for VM entries
        if [[ "$line" =~ ^[[:space:]]*[0-9]+[[:space:]] ]]; then
            local vmid=$(echo "$line" | awk '{print $1}')
            local name=$(echo "$line" | awk '{print $2}')
            local status=$(echo "$line" | awk '{print $3}')
            whiptail_options+=("$vmid" "$name ($status)")
        fi
    done < <(qm list 2>/dev/null)

    if [ ${#whiptail_options[@]} -eq 0 ]; then
        whiptail --msgbox "No VMs found on this node." 10 60
        exit 1
    fi

    local selected_vm=$(whiptail --title "VM Selection" --menu "$prompt_text" 20 78 10 "${whiptail_options[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then 
        msg "Canceled." "$R"
        exit 1
    fi

    echo "$selected_vm"
}

# Get available physical disks and let the user choose
select_disk() {
    local prompt_text=$1
    local whiptail_options=()

    # Get physical disks using lsblk
    while IFS=$'\t' read -r device size model; do
        # Skip loop devices, partitions, and mounted disks
        if [[ ! "$device" =~ ^/dev/loop ]] && [[ ! "$device" =~ [0-9]$ ]] && [[ "$device" =~ ^/dev/sd[a-z]$|^/dev/nvme[0-9]+n[0-9]+$ ]]; then
            # Check if disk is not mounted
            if ! mount | grep -q "$device"; then
                whiptail_options+=("$device" "$size $model")
            fi
        fi
    done < <(lsblk -dnb -o NAME,SIZE,MODEL | awk '{printf "/dev/%s\t%s\t%s\n", $1, $2, substr($0, index($0,$3))}' | while read device size model; do
        # Convert size to human readable format
        if [ "$size" -gt 1073741824 ]; then
            size_gb=$((size / 1073741824))
            echo -e "$device\t${size_gb}GB\t$model"
        else
            size_mb=$((size / 1048576))
            echo -e "$device\t${size_mb}MB\t$model"
        fi
    done)

    if [ ${#whiptail_options[@]} -eq 0 ]; then
        whiptail --msgbox "No suitable unmounted physical disks found." 10 70
        exit 1
    fi

    local selected_disk=$(whiptail --title "Disk Selection" --menu "$prompt_text" 20 78 10 "${whiptail_options[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then 
        msg "Canceled." "$R"
        exit 1
    fi

    echo "$selected_disk"
}

# Get available SCSI controllers for the VM
get_next_scsi_id() {
    local vmid=$1
    local used_ids=$(qm config "$vmid" 2>/dev/null | grep -E '^scsi[0-9]+:' | sed 's/^scsi\([0-9]\+\):.*/\1/' | sort -n)
    
    for i in {0..30}; do
        if ! echo "$used_ids" | grep -q "^$i$"; then
            echo "$i"
            return
        fi
    done
    
    echo "-1"  # No available slots
}

# --- Main Logic ---

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    msg "This script must be run as root." "$R"
    exit 1
fi

# Install dependencies
install_package "whiptail"

# Welcome message
whiptail --title "Proxmox Disk Passthrough Setup" --msgbox "This script will help you configure disk passthrough for a Proxmox VM.\n\nYou will:\n1. Select a VM\n2. Choose a physical disk to passthrough\n3. Configure the passthrough settings" 12 70
if [ $? -ne 0 ]; then 
    msg "Canceled." "$R"
    exit 1
fi

# --- Step 1: VM Selection ---
whiptail --title "Step 1: VM Selection" --msgbox "First, select the virtual machine that will receive the disk passthrough." 8 70
if [ $? -ne 0 ]; then 
    msg "Canceled." "$R"
    exit 1
fi

VMID=$(select_vm "Please select the VM for disk passthrough:")
VMNAME=$(qm config "$VMID" 2>/dev/null | grep "^name:" | cut -d' ' -f2- | tr -d '"')
[ -z "$VMNAME" ] && VMNAME="Unknown"

msg "Selected VM: $VMID ($VMNAME)" "$G"

# Check if VM is running
VM_STATUS=$(qm status "$VMID" 2>/dev/null | grep "^status:" | awk '{print $2}')
if [ "$VM_STATUS" == "running" ]; then
    if (whiptail --title "VM Running" --yesno "VM $VMID is currently running. The VM needs to be stopped to add disk passthrough.\n\nWould you like to stop the VM now?" 10 70); then
        msg "Stopping VM $VMID..." "$Y"
        qm stop "$VMID"
        # Wait for VM to stop
        while [ "$(qm status "$VMID" 2>/dev/null | grep "^status:" | awk '{print $2}')" != "stopped" ]; do
            sleep 2
        done
        msg "VM stopped successfully." "$G"
    else
        msg "Cannot proceed with VM running. Exiting." "$R"
        exit 1
    fi
fi

# --- Step 2: Disk Selection ---
whiptail --title "Step 2: Disk Selection" --msgbox "Now select the physical disk you want to passthrough to the VM.\n\nWARNING: The selected disk will be directly accessed by the VM. Make sure it doesn't contain important data or is not being used by the host system." 12 70
if [ $? -ne 0 ]; then 
    msg "Canceled." "$R"
    exit 1
fi

DISK=$(select_disk "Please select the physical disk to passthrough:")

# Get disk information
DISK_INFO=$(lsblk -no SIZE,MODEL "$DISK" 2>/dev/null | head -1)
msg "Selected disk: $DISK ($DISK_INFO)" "$G"

# Confirmation
if ! (whiptail --title "Confirmation" --yesno "You are about to passthrough the following disk to VM $VMID:\n\nDisk: $DISK\nInfo: $DISK_INFO\nVM: $VMID ($VMNAME)\n\nThis will give the VM direct access to this physical disk.\n\nDo you want to continue?" 15 70); then
    msg "Operation canceled by user." "$Y"
    exit 0
fi

# --- Step 3: Passthrough Configuration ---
msg "Step 3: Configuring disk passthrough..." "$Y"

# Get next available SCSI ID
SCSI_ID=$(get_next_scsi_id "$VMID")
if [ "$SCSI_ID" == "-1" ]; then
    msg "No available SCSI controller slots found for VM $VMID." "$R"
    exit 1
fi

msg "Using SCSI controller ID: $SCSI_ID" "$G"

# Configure disk passthrough
msg "Adding disk passthrough to VM configuration..." "$Y"
if qm set "$VMID" --scsi${SCSI_ID} "$DISK" 2>/dev/null; then
    msg "Disk passthrough configured successfully!" "$G"
else
    # Try with backup=0 option
    if qm set "$VMID" --scsi${SCSI_ID} "${DISK},backup=0" 2>/dev/null; then
        msg "Disk passthrough configured successfully!" "$G"
    else
        msg "Failed to configure disk passthrough." "$R"
        exit 1
    fi
fi

# --- Step 4: Final Configuration ---
msg "Updating VM configuration for optimal disk performance..." "$Y"

# Set SCSI controller to VirtIO SCSI if not already set
CURRENT_SCSIHW=$(qm config "$VMID" 2>/dev/null | grep "^scsihw:" | cut -d' ' -f2)
if [ "$CURRENT_SCSIHW" != "virtio-scsi-pci" ]; then
    qm set "$VMID" --scsihw virtio-scsi-pci 2>/dev/null
    msg "Set SCSI controller to VirtIO SCSI for better performance." "$G"
fi

# Ask about starting VM
START_VM="No"
if (whiptail --title "Start VM?" --yesno "Disk passthrough configuration is complete.\n\nWould you like to start the VM now?" 10 60); then
    msg "Starting VM $VMID..." "$Y"
    qm start "$VMID" 2>/dev/null
    START_VM="Yes"
fi

# --- Final Summary ---
whiptail --title "Configuration Complete!" --msgbox "Disk passthrough has been successfully configured.\n\nPlease check the summary information in the terminal below." 10 70

msg "--- Disk Passthrough Summary ---" "$B"
msg "VM ID: $VMID" "$G"
msg "VM Name: $VMNAME" "$G"
msg "Passthrough Disk: $DISK" "$G"
msg "Disk Info: $DISK_INFO" "$G"
msg "SCSI Controller: scsi$SCSI_ID" "$G"
msg "SCSI Hardware: virtio-scsi-pci" "$G"
msg "VM Started: $START_VM" "$G"
msg "--------------------------------" "$B"
msg "The physical disk is now directly accessible from the VM." "$Y"
msg "You can manage the VM from the Proxmox web interface." "$Y"