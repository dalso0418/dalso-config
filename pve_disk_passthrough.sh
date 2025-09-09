#!/bin/bash

# Color Palette
G='\033[1;32m'
R='\033[0;31m'
B='\033[0;34m'
Y='\033[0;33m'
N='\033[0m'

# Cleanup function
cleanup() {
    echo ""
    msg "Operation interrupted. Exiting..." "$R"
    # Kill any background whiptail processes
    pkill -f whiptail 2>/dev/null
    exit 130
}

# Signal handlers - more comprehensive
trap cleanup SIGINT SIGTERM SIGQUIT
# Also handle EXIT to ensure cleanup
trap 'pkill -f whiptail 2>/dev/null' EXIT

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
    local exit_status=$?
    if [ $exit_status -ne 0 ]; then 
        msg "Canceled." "$R"
        exit $exit_status
    fi

    echo "$selected_vm"
}

# Get available physical disks and let the user choose
select_disk() {
    local prompt_text=$1
    local whiptail_options=()

    # Get physical disks using lsblk and find by-id paths
    while IFS=$'\t' read -r device size model by_ids; do
        # Debug: uncomment to see what we're getting
        # echo "DEBUG: device=$device, size=$size, model=$model, by_ids=[$by_ids]" >&2
        # Skip loop devices, partitions, and mounted disks
        if [[ ! "$device" =~ ^/dev/loop ]] && [[ ! "$device" =~ [0-9]$ ]] && [[ "$device" =~ ^/dev/sd[a-z]$|^/dev/nvme[0-9]+n[0-9]+$ ]]; then
            # Check if disk is not mounted
            if ! mount | grep -q "$device"; then
                local by_id_path=""
                local display_name=$(basename "$device")
                
                # Find the best by-id path from the found paths
                if [ -n "$by_ids" ]; then
                    # Split by_ids by space and find the best one
                    for id_path in $by_ids; do
                        local id_basename=$(basename "$id_path")
                        # Prefer wwn-, ata-, nvme-, scsi- over others
                        if [[ "$id_basename" =~ ^(wwn-|ata-|nvme-|scsi-) ]]; then
                            by_id_path="$id_path"
                            break
                        elif [ -z "$by_id_path" ] && [[ ! "$id_basename" =~ ^(dm-|md-) ]]; then
                            by_id_path="$id_path"
                        fi
                    done
                fi
                
                # If no by-id path found, fall back to device name
                if [ -z "$by_id_path" ]; then
                    by_id_path="$device"
                    whiptail_options+=("$by_id_path" "$display_name - $size $model [No Stable ID]")
                else
                    local id_type=$(basename "$by_id_path" | cut -d'-' -f1 | tr '[:lower:]' '[:upper:]')
                    whiptail_options+=("$by_id_path" "$display_name - $size $model [$id_type]")
                fi
            fi
        fi
    done < <(lsblk -dnb -o NAME,SIZE,MODEL | awk 'NR>1{
        dev=$1; 
        size=$2;
        model=substr($0, index($0,$3));
        # Convert size to human readable format
        if (size > 1073741824) {
            size_human=int(size/1073741824) "GB"
        } else {
            size_human=int(size/1048576) "MB"
        }
        printf "/dev/%s\t%s\t%s\t", dev, size_human, model;
        system("find /dev/disk/by-id -lname \"*" dev "\" -printf \" %p\"");
        print "";
    }' | grep -v -E 'part|lvm')

    if [ ${#whiptail_options[@]} -eq 0 ]; then
        whiptail --msgbox "No suitable unmounted physical disks found." 10 70
        exit 1
    fi

    local selected_disk=$(whiptail --title "Disk Selection" --menu "$prompt_text" 25 120 15 "${whiptail_options[@]}" 3>&1 1>&2 2>&3)
    local exit_status=$?
    if [ $exit_status -ne 0 ]; then 
        msg "Canceled." "$R"
        exit $exit_status
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

# Get available SATA controllers for the VM
get_next_sata_id() {
    local vmid=$1
    local used_ids=$(qm config "$vmid" 2>/dev/null | grep -E '^sata[0-9]+:' | sed 's/^sata\([0-9]\+\):.*/\1/' | sort -n)
    
    for i in {0..5}; do
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
if ! whiptail --title "Proxmox Disk Passthrough Setup" --yesno "This script will help you configure disk passthrough for a Proxmox VM.\n\nYou will:\n1. Select a VM\n2. Choose a physical disk to passthrough\n3. Configure the passthrough settings\n\nDo you want to continue?" 15 70; then
    msg "Operation canceled by user." "$Y"
    exit 0
fi

# --- Step 1: VM Selection ---
if ! whiptail --title "Step 1: VM Selection" --yesno "First, select the virtual machine that will receive the disk passthrough.\n\nReady to continue?" 10 70; then
    msg "Operation canceled by user." "$Y"
    exit 0
fi

VMID=$(select_vm "Please select the VM for disk passthrough:")
VMNAME=$(qm config "$VMID" 2>/dev/null | grep "^name:" | cut -d' ' -f2- | tr -d '"')
[ -z "$VMNAME" ] && VMNAME="Unknown"

msg "Selected VM: $VMID ($VMNAME)" "$G"

# Check if VM is running
VM_STATUS=$(qm status "$VMID" 2>/dev/null | grep "^status:" | awk '{print $2}')
if [ "$VM_STATUS" == "running" ]; then
    if whiptail --title "VM Running" --yesno "VM $VMID is currently running. The VM needs to be stopped to add disk passthrough.\n\nWould you like to stop the VM now?" 10 70; then
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

# --- Step 2: Disk Bus Type Selection ---
if ! whiptail --title "Step 2: Disk Bus Type" --yesno "Select the disk bus type for the passthrough disk.\n\nSCSI: Better performance, supports more devices\nSATA: Better compatibility, native SATA interface\n\nReady to choose bus type?" 12 70; then
    msg "Operation canceled by user." "$Y"
    exit 0
fi

BUS_CHOICE=$(whiptail --title "Disk Bus Type" --menu "Select the disk bus type for the passthrough disk:" 15 60 2 \
"1" "SCSI (VirtIO SCSI)" \
"2" "SATA (Native SATA)" 3>&1 1>&2 2>&3)
exit_status=$?
if [ $exit_status -ne 0 ]; then 
    msg "Canceled." "$R"
    exit $exit_status
fi

case $BUS_CHOICE in
    1) 
        BUS_TYPE="scsi"
        BUS_NAME="SCSI"
        ;;
    2) 
        BUS_TYPE="sata"
        BUS_NAME="SATA"
        ;;
    *) 
        msg "Invalid choice. Exiting." "$R"
        exit 1
        ;;
esac

msg "Selected bus type: $BUS_NAME" "$G"

# --- Step 3: Disk Selection ---
if ! whiptail --title "Step 3: Disk Selection" --yesno "Now select the physical disk you want to passthrough to the VM.\n\nWARNING: The selected disk will be directly accessed by the VM. Make sure it doesn't contain important data or is not being used by the host system.\n\nReady to select disk?" 14 70; then
    msg "Operation canceled by user." "$Y"
    exit 0
fi

DISK=$(select_disk "Please select the physical disk to passthrough:")

# Get disk information
DISK_INFO=$(lsblk -no SIZE,MODEL "$DISK" 2>/dev/null | head -1)
# Show user-friendly disk info
if [[ "$DISK" =~ /dev/disk/by-id/ ]]; then
    DISK_NAME=$(basename "$DISK")
    DEVICE_PATH=$(readlink -f "$DISK" 2>/dev/null || echo "$DISK")
    msg "Selected disk: $(basename "$DEVICE_PATH") -> $DISK_NAME" "$G"
    msg "Stable path: $DISK" "$B"
else
    msg "Selected disk: $DISK ($DISK_INFO)" "$G"
fi

# Confirmation
CONFIRM_TEXT="You are about to passthrough the following disk to VM $VMID:\n\n"
if [[ "$DISK" =~ /dev/disk/by-id/ ]]; then
    CONFIRM_TEXT+="Physical Device: $(basename "$(readlink -f "$DISK" 2>/dev/null || echo "$DISK")")\n"
    CONFIRM_TEXT+="Stable ID: $(basename "$DISK")\n"
else
    CONFIRM_TEXT+="Disk: $DISK\n"
fi
CONFIRM_TEXT+="Bus Type: $BUS_NAME\nInfo: $DISK_INFO\nVM: $VMID ($VMNAME)\n\nThis will give the VM direct access to this physical disk.\n\nDo you want to continue?"

if ! whiptail --title "Confirmation" --yesno "$CONFIRM_TEXT" 18 80; then
    msg "Operation canceled by user." "$Y"
    exit 0
fi

# --- Step 4: Passthrough Configuration ---
msg "Step 4: Configuring disk passthrough..." "$Y"

# Get next available controller ID based on bus type
if [ "$BUS_TYPE" == "scsi" ]; then
    CONTROLLER_ID=$(get_next_scsi_id "$VMID")
    CONTROLLER_TYPE="SCSI"
else
    CONTROLLER_ID=$(get_next_sata_id "$VMID")
    CONTROLLER_TYPE="SATA"
fi

if [ "$CONTROLLER_ID" == "-1" ]; then
    msg "No available $CONTROLLER_TYPE controller slots found for VM $VMID." "$R"
    exit 1
fi

msg "Using $CONTROLLER_TYPE controller ID: $CONTROLLER_ID" "$G"

# Configure disk passthrough
msg "Adding disk passthrough to VM configuration..." "$Y"
if qm set "$VMID" --${BUS_TYPE}${CONTROLLER_ID} "$DISK" 2>/dev/null; then
    msg "Disk passthrough configured successfully!" "$G"
else
    # Try with backup=0 option
    if qm set "$VMID" --${BUS_TYPE}${CONTROLLER_ID} "${DISK},backup=0" 2>/dev/null; then
        msg "Disk passthrough configured successfully!" "$G"
    else
        msg "Failed to configure disk passthrough." "$R"
        exit 1
    fi
fi

# --- Step 5: Final Configuration ---
msg "Step 5: Updating VM configuration for optimal performance..." "$Y"

# Set appropriate controller for better performance
if [ "$BUS_TYPE" == "scsi" ]; then
    # Set SCSI controller to VirtIO SCSI if not already set
    CURRENT_SCSIHW=$(qm config "$VMID" 2>/dev/null | grep "^scsihw:" | cut -d' ' -f2)
    if [ "$CURRENT_SCSIHW" != "virtio-scsi-pci" ]; then
        qm set "$VMID" --scsihw virtio-scsi-pci 2>/dev/null
        msg "Set SCSI controller to VirtIO SCSI for better performance." "$G"
    fi
    CONTROLLER_HARDWARE="virtio-scsi-pci"
else
    # SATA doesn't need special controller setup
    CONTROLLER_HARDWARE="AHCI (native)"
fi

# Ask about starting VM
START_VM="No"
if whiptail --title "Start VM?" --yesno "Disk passthrough configuration is complete.\n\nWould you like to start the VM now?" 10 60; then
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
msg "Bus Type: $BUS_NAME" "$G"
msg "Controller: ${BUS_TYPE}${CONTROLLER_ID}" "$G"
msg "Controller Hardware: $CONTROLLER_HARDWARE" "$G"
msg "VM Started: $START_VM" "$G"
msg "--------------------------------" "$B"
msg "The physical disk is now directly accessible from the VM." "$Y"
msg "You can manage the VM from the Proxmox web interface." "$Y"