#!/usr/bin/env bash

# Shared VM configuration used by setup_kvm_windows.sh and start_win_vm.sh.
# Edit this file if you want both scripts to stay in sync.

VM_DIR="/home/ahmadzanisy/win_vm"
VM_NAME="windows-vm"
VM_DISK_NAME="windows10.qcow2"
VIRTIO_ISO_NAME="virtio-win.iso"
WIN_ISO_NAME="windows.iso"
VM_DISK_SIZE="100G"
VM_RAM_MB="12288"
VM_SMP_SOCKETS="1"
VM_SMP_CORES="4"
VM_SMP_THREADS="2"
VM_RDP_PORT="2222"
VM_NET_DEVICE="e1000e"
