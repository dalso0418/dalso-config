#!/bin/bash

# 필요한 패키지 확인 및 설치
install_package() {
    local package=$1
    if ! dpkg -l | grep -q "^ii  $package "; then
        echo "$package 패키지가 설치되어 있지 않습니다. 설치를 진행합니다..."
        apt-get update -y > /dev/null 2>&1
        apt-get install -y $package > /dev/null 2>&1
        echo "$package 패키지 설치가 완료되었습니다."
    else
        echo "$package 패키지가 이미 설치되어 있습니다."
    fi
}

# jq 및 unzip 패키지 설치 확인
install_package "jq"
install_package "unzip"

# 이미지 파일 다운로드 및 압축 해제 함수
download_and_extract_image() {
    local url=$1
    local zip_path=$2
    local img_path=$3
    wget $url -O $zip_path
    unzip -o $zip_path -d $(dirname $img_path)
}

# 디스크 추가 함수
add_disk() {
    local DISK_TYPE=$1
    local STORAGE_NAME=$2
    local DISK_SIZE=$3
    local DISK_INDEX=$4

    if [ "$DISK_TYPE" == "sata" ]; then
        qm set $VMID --sata${DISK_INDEX} $STORAGE_NAME:$DISK_SIZE
    elif [ "$DISK_TYPE" == "scsi" ]; then
        qm set $VMID --scsihw virtio-scsi-single --scsi${DISK_INDEX} $STORAGE_NAME:$DISK_SIZE
    fi
}

# 디스크 타입 검증 함수
validate_disk_type() {
    local DISK_TYPE=$1
    if [ "$DISK_TYPE" != "sata" ] && [ "$DISK_TYPE" != "scsi" ]; then
        echo "잘못된 디스크 타입입니다. sata 또는 scsi를 입력해 주세요."
        return 1
    fi
    return 0
}

# 디스크 수 검증 함수
validate_disk_count() {
    local COUNT=$1
    if [[ ! "$COUNT" =~ ^[1-9]$ ]]; then
        echo "디스크 수는 1부터 9까지의 숫자여야 합니다."
        return 1
    fi
    return 0
}

# 사용자 입력 받기
read -p "VM 번호를 입력하세요 (숫자): " VMID
read -p "VM 이름을 입력하세요 : " VMNAME
read -p "CPU 코어 수를 입력하세요 : " CORES
read -p "RAM 크기를 MB 단위로 입력하세요 (ex)4096=4G: " RAM

# 현재 노드 이름 가져오기
NODE=$(hostname)

# Proxmox에서 현재 노드의 스토리지 목록 가져오기
echo "현재 노드에서 사용 가능한 스토리지 목록 및 용량:"
pvesh get /nodes/$NODE/storage

# 디스크 수 입력 받기
while true; do
    read -p "사용할 디스크 수를 입력하세요: " DISK_COUNT
    if validate_disk_count $DISK_COUNT; then
        break
    fi
done

# 디스크 정보 입력 받기 및 추가
declare -a DISK_ARRAY
for (( i=0; i<$DISK_COUNT; i++ ))
do
    echo "디스크 $((i+1)) 설정:"
    while true; do
        read -p "디스크 타입을 입력하세요 (sata 또는 scsi): " DISK_TYPE
        if validate_disk_type $DISK_TYPE; then
            break
        fi
    done
    read -p "스토리지 이름을 입력하세요 (ex. local-LVM): " STORAGE_NAME
    read -p "디스크 크기를 GB 단위로 입력하세요: " DISK_SIZE
    DISK_ARRAY+=("$DISK_TYPE $STORAGE_NAME $DISK_SIZE")
done

# 네트워크 브릿지 목록 출력
echo "사용 가능한 네트워크 브릿지 목록 :"
pvesh get /nodes/$NODE/network

# 네트워크 브릿지 입력 받기
read -p "사용할 네트워크 브릿지 이름을 입력하세요 (ex. vmbr0) : " NET_BRIDGE

# 이미지 파일 선택
echo "사용할 이미지 파일을 선택하세요:"
echo "1. m-shell (m-shell.img)"
echo "2. RR (rr.img.zip)"
echo "3. xTCRP (xtcrp.img)"
read -p "선택 (1 - 3): " IMAGE_CHOICE

# 이미지 파일 경로 설정
if [ "$IMAGE_CHOICE" -eq 1 ]; then
    IMG_URL="https://github.com/PeterSuh-Q3/tinycore-redpill/releases/download/v1.2.0.0/tinycore-redpill.v1.2.0.0.m-shell.img.gz"
    IMG_PATH="/var/lib/vz/template/iso/m-shell.img"
    wget $IMG_URL -O /var/lib/vz/template/iso/m-shell.img.gz
    gunzip -f /var/lib/vz/template/iso/m-shell.img.gz
elif [ "$IMAGE_CHOICE" -eq 2 ]; then
    IMG_URL="https://github.com/RROrg/rr/releases/download/25.1.4/rr-25.1.4.img.zip"
    IMG_ZIP_PATH="/var/lib/vz/template/iso/rr-25.1.4.img.zip"
    IMG_PATH="/var/lib/vz/template/iso/rr.img"
    download_and_extract_image $IMG_URL $IMG_ZIP_PATH $IMG_PATH
elif [ "$IMAGE_CHOICE" -eq 3 ]; then
    IMG_URL="https://github.com/PeterSuh-Q3/tinycore-redpill/releases/download/v1.2.0.0/tinycore-redpill.v1.2.0.0.xtcrp.img.gz"
    IMG_PATH="/var/lib/vz/template/iso/xtcrp.img"
    wget $IMG_URL -O /var/lib/vz/template/iso/xtcrp.img.gz
    gunzip -f /var/lib/vz/template/iso/xtcrp.img.gz
else
    echo "잘못된 선택입니다. 1 부터 3까지의 숫자를 입력하세요."
    exit 1
fi

# VM 생성
qm create $VMID --name $VMNAME --memory $RAM --cores $CORES --net0 virtio,bridge=$NET_BRIDGE --bios seabios --ostype l26

# 디스크 추가
for (( i=0; i<$DISK_COUNT; i++ ))
do
    DISK_INFO=(${DISK_ARRAY[$i]})
    add_disk ${DISK_INFO[0]} ${DISK_INFO[1]} ${DISK_INFO[2]} $i
done

# 부팅 순서 설정 (net0 우선)
qm set $VMID --boot order=net0

# 커스텀 args 추가
qm set $VMID --args "-drive 'if=none,id=synoboot,format=raw,file=$IMG_PATH' -device 'qemu-xhci,addr=0x18' -device 'usb-storage,drive=synoboot,bootindex=5'"

# VM 시작
qm start $VMID

# 요약 정보 출력
echo "-----------------------------------------------------"
echo "VM 생성 및 시작이 완료되었습니다!"
echo "VM ID: $VMID"
echo "VM 이름: $VMNAME"
echo "CPU 코어 수: $CORES"
echo "RAM 크기: $RAM MB"
echo "네트워크 브릿지: $NET_BRIDGE"
echo "이미지 파일: $IMG_PATH"
echo "디스크 수: $DISK_COUNT"

for (( i=0; i<$DISK_COUNT; i++ ))
do
    DISK_INFO=(${DISK_ARRAY[$i]})
    echo "디스크 $((i+1)) - 타입: ${DISK_INFO[0]}, 스토리지: ${DISK_INFO[1]}, 크기: ${DISK_INFO[2]} GB"
done

echo "VM 생성 및 시작이 완료되었습니다!"
