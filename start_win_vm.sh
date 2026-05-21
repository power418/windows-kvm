#!/usr/bin/env bash

# ==============================================================================
# SCRIPT PELUNCUR WINDOWS VM (QEMU/KVM)
# ==============================================================================
# Script ini membaca config bersama dari vm_config.sh supaya setup dan boot
# tetap saling terhubung.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/vm_config.sh"

if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
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

VM_DISK="$VM_DIR/$VM_DISK_NAME"
VIRTIO_ISO="$VM_DIR/$VIRTIO_ISO_NAME"
WIN_ISO="$VM_DIR/$WIN_ISO_NAME"

mkdir -p "$VM_DIR"

# Pastikan disk ada
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

echo "Memulai Windows VM dengan optimasi tinggi..."
echo "  - CPU: $((VM_SMP_CORES * VM_SMP_THREADS)) vCPUs (Host Passthrough)"
echo "  - RAM: ${VM_RAM_MB} MB (Akselerasi KVM)"

# Parameter QEMU Berkinerja Tinggi
# Disk pakai SATA/AHCI dulu supaya installer Windows langsung melihat storage.
qemu-system-x86_64 \
  -enable-kvm \
  -name "$VM_NAME",process="$VM_NAME" \
  -machine type=q35,accel=kvm \
  -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vendor_id=genuineintel,kvm=off \
  -smp sockets="$VM_SMP_SOCKETS",cores="$VM_SMP_CORES",threads="$VM_SMP_THREADS" \
  -m "$VM_RAM_MB" \
  -mem-prealloc \
  -rtc base=localtime,clock=host \
  -device pcie-root-port,id=pcie.1,bus=pcie.0,chassis=1 \
  -device ich9-ahci,id=sata \
  -drive file="$VM_DISK",if=none,id=hd0,format=qcow2,cache=writeback,discard=on \
  -device ide-hd,drive=hd0,bus=sata.0,bootindex=1 \
  -device ide-cd,drive=cd0,bus=sata.1,bootindex=2 \
  -drive file="$WIN_ISO",if=none,id=cd0,media=cdrom \
  -device ide-cd,drive=cd1,bus=sata.2,bootindex=3 \
  -drive file="$VIRTIO_ISO",if=none,id=cd1,media=cdrom \
  -netdev "user,id=net0,hostfwd=tcp::${VM_RDP_PORT}-:3389" \
  -device "${VM_NET_DEVICE},netdev=net0" \
  -vga virtio \
  -display sdl,gl=on \
  -device ich9-intel-hda -device hda-duplex \
  -usb -device usb-tablet
