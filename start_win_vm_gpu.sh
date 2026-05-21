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
: "${VM_NAME:=Windows-AutoCAD-VM}"
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

mkdir -p "$VM_DIR"

if [ ! -f "$VM_DISK" ]; then
  echo "Virtual disk tidak ditemukan! Membuat baru..."
  qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"
fi

if [ ! -f "$WIN_ISO" ]; then
  echo "ISO Windows tidak ditemukan: $WIN_ISO"
  echo "Letakkan installer Windows sebagai $VM_DIR/windows.iso"
  exit 1
fi

if [ ! -f "$VIRTIO_ISO" ]; then
  echo "VirtIO ISO tidak ditemukan: $VIRTIO_ISO"
  exit 1
fi

HOST_GPU_SYSFS="/sys/bus/pci/devices/$GPU_HOST_PCI"
if [ ! -e "$HOST_GPU_SYSFS" ]; then
  echo "Host GPU device tidak ditemukan di $HOST_GPU_SYSFS"
  echo "Cek kembali GPU_HOST_PCI di gpu_config.sh"
  exit 1
fi

HOST_GPU_DRIVER=""
if [ -L "$HOST_GPU_SYSFS/driver" ]; then
  HOST_GPU_DRIVER="$(basename "$(readlink -f "$HOST_GPU_SYSFS/driver")")"
fi

if [ "$HOST_GPU_DRIVER" != "vfio-pci" ]; then
  echo "Peringatan: $GPU_HOST_PCI masih terikat ke driver '$HOST_GPU_DRIVER'."
  echo "Passthrough akan gagal sampai GPU dibind ke vfio-pci dan host di-reboot."
fi

echo "Memulai Windows VM dengan NVIDIA passthrough..."
echo "  - GPU: ${GPU_NAME:-NVIDIA RTX 3050 Mobile} (${GPU_HOST_PCI})"
echo "  - Audio GPU: ${GPU_AUDIO_PCI}"
echo "  - CPU: $((VM_SMP_CORES * VM_SMP_THREADS)) vCPUs"
echo "  - RAM: ${VM_RAM_MB} MB"

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
