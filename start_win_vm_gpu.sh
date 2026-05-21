#!/usr/bin/env bash

# ==============================================================================
# WINDOWS VM LAUNCHER WITH NVIDIA GPU PASSTHROUGH
# ==============================================================================
# Use this script after GPU passthrough host setup is applied and the RTX 3050
# has been bound to vfio-pci on the host.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_CONFIG_FILE="$SCRIPT_DIR/vm_config.sh"
GPU_CONFIG_FILE="$SCRIPT_DIR/gpu_config.sh"

if [ -f "$VM_CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$VM_CONFIG_FILE"
fi

if [ -f "$GPU_CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$GPU_CONFIG_FILE"
else
  echo "gpu_config.sh tidak ditemukan di: $GPU_CONFIG_FILE"
  echo "Jalankan gpu_passthrough_setup.sh dulu."
  exit 1
fi

: "${VM_DIR:=$SCRIPT_DIR}"
: "${VM_NAME:=windows-vm}"
: "${VM_DISK_NAME:=windows10.qcow2}"
: "${VIRTIO_ISO_NAME:=virtio-win.iso}"
: "${WIN_ISO_NAME:=windows.iso}"
: "${VM_DISK_SIZE:=100G}"
: "${VM_RAM_MB:=12288}"
: "${VM_SMP_SOCKETS:=1}"
: "${VM_SMP_CORES:=4}"
: "${VM_SMP_THREADS:=2}"
: "${VM_RDP_PORT:=2222}"
: "${VM_NET_DEVICE:=e1000e}"
: "${GPU_HOST_PCI:=0000:01:00.0}"
: "${GPU_AUDIO_PCI:=0000:01:00.1}"
: "${GPU_USE_VIRTIO_DISPLAY:=yes}"

VM_DISK="$VM_DIR/$VM_DISK_NAME"
VIRTIO_ISO="$VM_DIR/$VIRTIO_ISO_NAME"
WIN_ISO="$VM_DIR/$WIN_ISO_NAME"

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

ok() {
  log "OK   $*"
}

warn() {
  log "WARN $*"
}

fail() {
  log "FAIL $*"
}

mkdir -p "$VM_DIR"

log "Memulai Windows VM dengan NVIDIA passthrough"
log "  - VM name: $VM_NAME"
log "  - GPU: ${GPU_NAME:-NVIDIA RTX 3050 Mobile} (${GPU_HOST_PCI})"
log "  - Audio GPU: ${GPU_AUDIO_PCI}"
log "  - CPU: $((VM_SMP_CORES * VM_SMP_THREADS)) vCPUs"
log "  - RAM: ${VM_RAM_MB} MB"

if [ ! -f "$VM_DISK" ]; then
  fail "Virtual disk tidak ditemukan: $VM_DISK"
  log "Membuat virtual disk baru..."
  qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"
  ok "Virtual disk dibuat"
else
  ok "Virtual disk ditemukan: $VM_DISK"
fi

if [ ! -f "$WIN_ISO" ]; then
  fail "ISO Windows tidak ditemukan: $WIN_ISO"
  log "Letakkan installer Windows sebagai $VM_DIR/windows.iso"
  exit 1
else
  ok "ISO Windows ditemukan: $WIN_ISO"
fi

if [ ! -f "$VIRTIO_ISO" ]; then
  fail "VirtIO ISO tidak ditemukan: $VIRTIO_ISO"
  exit 1
else
  ok "VirtIO ISO ditemukan: $VIRTIO_ISO"
fi

HOST_GPU_SYSFS="/sys/bus/pci/devices/$GPU_HOST_PCI"
HOST_AUDIO_SYSFS="/sys/bus/pci/devices/$GPU_AUDIO_PCI"

if [ ! -e "$HOST_GPU_SYSFS" ]; then
  fail "Host GPU device tidak ditemukan di $HOST_GPU_SYSFS"
  log "Cek kembali GPU_HOST_PCI di gpu_config.sh"
  exit 1
else
  ok "Host GPU device ditemukan: $GPU_HOST_PCI"
fi

if [ ! -e "$HOST_AUDIO_SYSFS" ]; then
  fail "Host audio device tidak ditemukan di $HOST_AUDIO_SYSFS"
  log "Cek kembali GPU_AUDIO_PCI di gpu_config.sh"
  exit 1
else
  ok "Host audio device ditemukan: $GPU_AUDIO_PCI"
fi

HOST_GPU_DRIVER=""
if [ -L "$HOST_GPU_SYSFS/driver" ]; then
  HOST_GPU_DRIVER="$(basename "$(readlink -f "$HOST_GPU_SYSFS/driver")")"
fi

HOST_AUDIO_DRIVER=""
if [ -L "$HOST_AUDIO_SYSFS/driver" ]; then
  HOST_AUDIO_DRIVER="$(basename "$(readlink -f "$HOST_AUDIO_SYSFS/driver")")"
fi

READY=1
BOOT_CMDLINE="$(cat /proc/cmdline 2>/dev/null || true)"

if [ "$HOST_GPU_DRIVER" != "vfio-pci" ]; then
  warn "GPU driver aktif: ${HOST_GPU_DRIVER:-none}"
  fail "GPU masih terikat ke driver '${HOST_GPU_DRIVER:-none}'."
  READY=0
else
  ok "GPU driver aktif: vfio-pci"
fi

if [ "$HOST_AUDIO_DRIVER" != "vfio-pci" ]; then
  warn "Audio driver aktif: ${HOST_AUDIO_DRIVER:-none}"
  fail "Audio function belum bind ke vfio-pci."
  READY=0
else
  ok "Audio driver aktif: vfio-pci"
fi

if [[ "$BOOT_CMDLINE" == *"intel_iommu=on"* || "$BOOT_CMDLINE" == *"amd_iommu=on"* ]]; then
  ok "Kernel IOMMU param aktif"
else
  fail "Kernel cmdline belum memuat intel_iommu=on atau amd_iommu=on."
  READY=0
fi

if [[ "$BOOT_CMDLINE" == *"iommu=pt"* ]]; then
  ok "Kernel passthrough param aktif: iommu=pt"
else
  warn "Kernel cmdline belum memuat iommu=pt."
fi

GPU_IOMMU_GROUP=""
if [ -L "$HOST_GPU_SYSFS/iommu_group" ]; then
  GPU_IOMMU_GROUP="$(basename "$(readlink -f "$HOST_GPU_SYSFS/iommu_group")")"
  ok "GPU IOMMU group: $GPU_IOMMU_GROUP"
else
  fail "GPU tidak punya iommu_group."
  READY=0
fi

GPU_AUDIO_IOMMU_GROUP=""
if [ -L "$HOST_AUDIO_SYSFS/iommu_group" ]; then
  GPU_AUDIO_IOMMU_GROUP="$(basename "$(readlink -f "$HOST_AUDIO_SYSFS/iommu_group")")"
  ok "Audio IOMMU group: $GPU_AUDIO_IOMMU_GROUP"
else
  fail "Audio device tidak punya iommu_group."
  READY=0
fi

if [ "$READY" -ne 1 ]; then
  log "Passthrough belum siap."
  log "Pastikan IOMMU aktif di BIOS/UEFI dan host sudah dibind ke vfio-pci."
  log "Kalau baru ubah setup, jalankan gpu_passthrough_setup.sh lalu reboot host."
  exit 1
fi

log "Semua prasyarat passthrough terdeteksi, menyiapkan QEMU..."
log "  - VirtIO display fallback: ${GPU_USE_VIRTIO_DISPLAY}"

QEMU_CMD=(
  qemu-system-x86_64
  -enable-kvm
  -name "${VM_NAME}-gpu",process="${VM_NAME}-gpu"
  -machine type=q35,accel=kvm
  -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vendor_id=genuineintel,kvm=off
  -smp "sockets=${VM_SMP_SOCKETS},cores=${VM_SMP_CORES},threads=${VM_SMP_THREADS}"
  -m "$VM_RAM_MB"
  -mem-prealloc
  -rtc base=localtime,clock=host
  -device pcie-root-port,id=pcie.1,bus=pcie.0,chassis=1
  -device ich9-ahci,id=sata
  -drive "file=${VM_DISK},if=none,id=hd0,format=qcow2,cache=writeback,discard=on"
  -device ide-hd,drive=hd0,bus=sata.0,bootindex=1
  -device ide-cd,drive=cd0,bus=sata.1,bootindex=2
  -drive "file=${WIN_ISO},if=none,id=cd0,media=cdrom"
  -device ide-cd,drive=cd1,bus=sata.2,bootindex=3
  -drive "file=${VIRTIO_ISO},if=none,id=cd1,media=cdrom"
  -netdev "user,id=net0,hostfwd=tcp::${VM_RDP_PORT}-:3389"
  -device "${VM_NET_DEVICE},netdev=net0"
)

if [ "${GPU_USE_VIRTIO_DISPLAY}" = "yes" ]; then
  QEMU_CMD+=( -vga virtio )
else
  QEMU_CMD+=( -vga none )
fi

QEMU_CMD+=(
  -display sdl,gl=on
  -device ich9-intel-hda
  -device hda-duplex
  -usb
  -device usb-tablet
  -device vfio-pci,host="${GPU_HOST_PCI}",x-vga=on
)

if [ -n "${GPU_AUDIO_PCI:-}" ]; then
  QEMU_CMD+=( -device "vfio-pci,host=${GPU_AUDIO_PCI}" )
fi

exec "${QEMU_CMD[@]}"
