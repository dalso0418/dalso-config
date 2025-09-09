# dalso-config

개인 서버 환경 구성을 위한 스크립트 모음입니다.

## 스크립트 목록 및 설명

| 스크립트 파일 | 설명 |
| --- | --- |
| `proxmox_temperature.sh` | Proxmox VE 웹 UI에 CPU 온도를 표시하기 위해 `lm-sensors`를 설치하고 관련 파일을 수정합니다. 원상 복구 기능을 포함합니다. |
| `pve_xpenol_install.sh` | Proxmox VE 환경에 Xpenology(Synology) VM을 자동으로 생성하고 설정합니다. |
| `pve_disk_passthrough.sh` | Proxmox VE 환경에서 물리 디스크를 VM에 직접 패스스루하는 작업을 대화형 인터페이스로 설정합니다. |
| `ubuntu24_config.sh` | Ubuntu 24.04 서버의 초기 설정을 자동화합니다. (호스트네임, 고정 IP, 타임존, Docker, Dockge 등) |
| `volume_move.sh` | Docker 볼륨을 백업하여 다른 서버로 이전하거나, 특정 로컬 경로의 데이터를 원격 서버와 동기화합니다. |
| `zabbix_install.sh` | Ubuntu 22.04/24.04에 Zabbix Agent 2를 설치하고 Zabbix 서버 정보를 설정합니다. |
| `.bashrc` | 다채로운 프롬프트와 유용한 alias가 포함된 Bash 쉘 설정 파일입니다. |

## 사용법

### .bashrc (Bash쉘 꾸미기) 적용
```bash
curl -o /root/.bashrc https://raw.githubusercontent.com/dalso0418/dalso-config/main/.bashrc
source /root/.bashrc
```

### 스크립트 실행
각 스크립트는 저장소를 클론한 후 직접 실행하거나, curl로 바로 다운로드하여 사용할 수 있습니다.

#### 방법 1: 저장소 클론 후 실행
```bash
git clone https://github.com/dalso0418/dalso-config.git
cd dalso-config
chmod +x *.sh
# 원하는 스크립트 실행
./ubuntu24_config.sh
```

#### 방법 2: 스크립트 직접 다운로드 및 실행
```bash
# Proxmox 디스크 패스스루 설정
curl -o pve_disk_passthrough.sh https://raw.githubusercontent.com/dalso0418/dalso-config/main/pve_disk_passthrough.sh
chmod +x pve_disk_passthrough.sh
./pve_disk_passthrough.sh

# Xpenology VM 자동 설치
curl -o pve_xpenol_install.sh https://raw.githubusercontent.com/dalso0418/dalso-config/main/pve_xpenol_install.sh
chmod +x pve_xpenol_install.sh
./pve_xpenol_install.sh

# Ubuntu 24.04 초기 설정
curl -o ubuntu24_config.sh https://raw.githubusercontent.com/dalso0418/dalso-config/main/ubuntu24_config.sh
chmod +x ubuntu24_config.sh
./ubuntu24_config.sh
```